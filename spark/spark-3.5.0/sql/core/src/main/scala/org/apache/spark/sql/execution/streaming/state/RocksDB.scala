/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.sql.execution.streaming.state

import java.io.File
import java.util.Locale
import javax.annotation.concurrent.GuardedBy

import scala.collection.{mutable, Map}
import scala.ref.WeakReference
import scala.util.Try

import org.apache.hadoop.conf.Configuration
import org.json4s.NoTypeHints
import org.json4s.jackson.Serialization
import org.rocksdb.{RocksDB => NativeRocksDB, _}
import org.rocksdb.TickerType._

import org.apache.spark.TaskContext
import org.apache.spark.internal.Logging
import org.apache.spark.sql.catalyst.util.CaseInsensitiveMap
import org.apache.spark.util.{NextIterator, Utils}

/**
 * Class representing a RocksDB instance that checkpoints version of data to DFS.
 * After a set of updates, a new version can be committed by calling `commit()`.
 * Any past version can be loaded by calling `load(version)`.
 *
 * @note This class is not thread-safe, so use it only from one thread.
 * @see [[RocksDBFileManager]] to see how the files are laid out in local disk and DFS.
 * @param dfsRootDir  Remote directory where checkpoints are going to be written
 * @param conf         Configuration for RocksDB
 * @param localRootDir Root directory in local disk that is used to working and checkpointing dirs
 * @param hadoopConf   Hadoop configuration for talking to the remote file system
 * @param loggingId    Id that will be prepended in logs for isolating concurrent RocksDBs
 */
class RocksDB(
    dfsRootDir: String,
    val conf: RocksDBConf,
    localRootDir: File = Utils.createTempDir(),
    hadoopConf: Configuration = new Configuration,
    loggingId: String = "") extends Logging {

  case class RocksDBSnapshot(checkpointDir: File, version: Long, numKeys: Long) {
    def close(): Unit = {
      silentDeleteRecursively(checkpointDir, s"Free up local checkpoint of snapshot $version")
    }
  }

  @volatile private var latestSnapshot: Option[RocksDBSnapshot] = None
  @volatile private var lastSnapshotVersion = 0L

  RocksDBLoader.loadLibrary()

  // Java wrapper objects linking to native RocksDB objects
  private val readOptions = new ReadOptions()  // used for gets
  // disable WAL since we flush explicitly on commit
  private val writeOptions = new WriteOptions().setDisableWAL(true)
  private val flushOptions = new FlushOptions().setWaitForFlush(true)  // wait for flush to complete

  private val bloomFilter = new BloomFilter()
  private val tableFormatConfig = new BlockBasedTableConfig()

  private val (writeBufferManager, lruCache) = RocksDBMemoryManager
    .getOrCreateRocksDBMemoryManagerAndCache(conf)

  tableFormatConfig.setBlockSize(conf.blockSizeKB * 1024)
  tableFormatConfig.setBlockCache(lruCache)
  tableFormatConfig.setFilterPolicy(bloomFilter)
  tableFormatConfig.setFormatVersion(conf.formatVersion)

  if (conf.boundedMemoryUsage) {
    tableFormatConfig.setCacheIndexAndFilterBlocks(true)
    tableFormatConfig.setCacheIndexAndFilterBlocksWithHighPriority(true)
    tableFormatConfig.setPinL0FilterAndIndexBlocksInCache(true)
  }

  private val columnFamilyOptions = new ColumnFamilyOptions()

  // Set RocksDB options around MemTable memory usage. By default, we let RocksDB
  // use its internal default values for these settings.
  if (conf.writeBufferSizeMB > 0L) {
    columnFamilyOptions.setWriteBufferSize(conf.writeBufferSizeMB * 1024 * 1024)
  }

  if (conf.maxWriteBufferNumber > 0L) {
    columnFamilyOptions.setMaxWriteBufferNumber(conf.maxWriteBufferNumber)
  }

  private val dbOptions =
    new Options(new DBOptions(), columnFamilyOptions) // options to open the RocksDB

  dbOptions.setCreateIfMissing(true)
  dbOptions.setTableFormatConfig(tableFormatConfig)
  dbOptions.setMaxOpenFiles(conf.maxOpenFiles)

  if (conf.boundedMemoryUsage) {
    dbOptions.setWriteBufferManager(writeBufferManager)
  }

  private val dbLogger = createLogger() // for forwarding RocksDB native logs to log4j
  dbOptions.setStatistics(new Statistics())
  private val nativeStats = dbOptions.statistics()

  private val workingDir = createTempDir("workingDir")
  private val fileManager = new RocksDBFileManager(dfsRootDir, createTempDir("fileManager"),
    hadoopConf, conf.compressionCodec, loggingId = loggingId)
  private val byteArrayPair = new ByteArrayPair()
  private val commitLatencyMs = new mutable.HashMap[String, Long]()
  private val acquireLock = new Object

  @volatile private var db: NativeRocksDB = _
  @volatile private var changelogWriter: Option[StateStoreChangelogWriter] = None
  private val enableChangelogCheckpointing: Boolean = conf.enableChangelogCheckpointing
  @volatile private var loadedVersion = -1L   // -1 = nothing valid is loaded
  @volatile private var numKeysOnLoadedVersion = 0L
  @volatile private var numKeysOnWritingVersion = 0L
  @volatile private var fileManagerMetrics = RocksDBFileManagerMetrics.EMPTY_METRICS

  @GuardedBy("acquireLock")
  @volatile private var acquiredThreadInfo: AcquiredThreadInfo = _

  /**
   * Load the given version of data in a native RocksDB instance.
   * Note that this will copy all the necessary file from DFS to local disk as needed,
   * and possibly restart the native RocksDB instance.
   */
  def load(version: Long, readOnly: Boolean = false): RocksDB = {
    assert(version >= 0)
    acquire()
    logInfo(s"Loading $version")
    try {
      if (loadedVersion != version) {
        closeDB()
        val latestSnapshotVersion = fileManager.getLatestSnapshotVersion(version)
        val metadata = fileManager.loadCheckpointFromDfs(latestSnapshotVersion, workingDir)
        loadedVersion = latestSnapshotVersion

        openDB()

        numKeysOnWritingVersion = if (!conf.trackTotalNumberOfRows) {
          // we don't track the total number of rows - discard the number being track
          -1L
        } else if (metadata.numKeys < 0) {
          // we track the total number of rows, but the snapshot doesn't have tracking number
          // need to count keys now
          countKeys()
        } else {
          metadata.numKeys
        }
        if (loadedVersion != version) replayChangelog(version)
        // After changelog replay the numKeysOnWritingVersion will be updated to
        // the correct number of keys in the loaded version.
        numKeysOnLoadedVersion = numKeysOnWritingVersion
        fileManagerMetrics = fileManager.latestLoadCheckpointMetrics
      }
      if (conf.resetStatsOnLoad) {
        nativeStats.reset
      }
      logInfo(s"Loaded $version")
    } catch {
      case t: Throwable =>
        loadedVersion = -1  // invalidate loaded data
        throw t
    }
    if (enableChangelogCheckpointing && !readOnly) {
      // Make sure we don't leak resource.
      changelogWriter.foreach(_.abort())
      changelogWriter = Some(fileManager.getChangeLogWriter(version + 1))
    }
    this
  }

  /**
   * Replay change log from the loaded version to the target version.
   */
  private def replayChangelog(endVersion: Long): Unit = {
    for (v <- loadedVersion + 1 to endVersion) {
      var changelogReader: StateStoreChangelogReader = null
      try {
        changelogReader = fileManager.getChangelogReader(v)
        changelogReader.foreach { case (key, value) =>
          if (value != null) {
            put(key, value)
          } else {
            remove(key)
          }
        }
      } finally {
        if (changelogReader != null) changelogReader.close()
      }
    }
    loadedVersion = endVersion
  }

  /**
   * Get the value for the given key if present, or null.
   * @note This will return the last written value even if it was uncommitted.
   */
  def get(key: Array[Byte]): Array[Byte] = {
    db.get(readOptions, key)
  }

  /**
   * Put the given value for the given key.
   * @note This update is not committed to disk until commit() is called.
   */
  def put(key: Array[Byte], value: Array[Byte]): Unit = {
    if (conf.trackTotalNumberOfRows) {
      val oldValue = db.get(readOptions, key)
      if (oldValue == null) {
        numKeysOnWritingVersion += 1
      }
    }
    db.put(writeOptions, key, value)
    changelogWriter.foreach(_.put(key, value))
  }

  /**
   * Remove the key if present.
   * @note This update is not committed to disk until commit() is called.
   */
  def remove(key: Array[Byte]): Unit = {
    if (conf.trackTotalNumberOfRows) {
      val value = db.get(readOptions, key)
      if (value != null) {
        numKeysOnWritingVersion -= 1
      }
    }
    db.delete(writeOptions, key)
    changelogWriter.foreach(_.delete(key))
  }

  /**
   * Get an iterator of all committed and uncommitted key-value pairs.
   */
  def iterator(): Iterator[ByteArrayPair] = {
    val iter = db.newIterator()
    logInfo(s"Getting iterator from version $loadedVersion")
    iter.seekToFirst()

    // Attempt to close this iterator if there is a task failure, or a task interruption.
    // This is a hack because it assumes that the RocksDB is running inside a task.
    Option(TaskContext.get()).foreach { tc =>
      tc.addTaskCompletionListener[Unit] { _ => iter.close() }
    }

    new NextIterator[ByteArrayPair] {
      override protected def getNext(): ByteArrayPair = {
        if (iter.isValid) {
          byteArrayPair.set(iter.key, iter.value)
          iter.next()
          byteArrayPair
        } else {
          finished = true
          iter.close()
          null
        }
      }
      override protected def close(): Unit = { iter.close() }
    }
  }

  private def countKeys(): Long = {
    val iter = db.newIterator()
    try {
      logInfo(s"Counting keys - getting iterator from version $loadedVersion")

      iter.seekToFirst()

      var keys = 0L
      while (iter.isValid) {
        keys += 1
        iter.next()
      }

      keys
    } finally {
      iter.close()
    }
  }

  def prefixScan(prefix: Array[Byte]): Iterator[ByteArrayPair] = {
    val iter = db.newIterator()
    iter.seek(prefix)

    // Attempt to close this iterator if there is a task failure, or a task interruption.
    Option(TaskContext.get()).foreach { tc =>
      tc.addTaskCompletionListener[Unit] { _ => iter.close() }
    }

    new NextIterator[ByteArrayPair] {
      override protected def getNext(): ByteArrayPair = {
        if (iter.isValid && iter.key().take(prefix.length).sameElements(prefix)) {
          byteArrayPair.set(iter.key, iter.value)
          iter.next()
          byteArrayPair
        } else {
          finished = true
          iter.close()
          null
        }
      }

      override protected def close(): Unit = { iter.close() }
    }
  }

  /**
   * Commit all the updates made as a version to DFS. The steps it needs to do to commits are:
   * - Flush all changes to disk
   * - Create a RocksDB checkpoint in a new local dir
   * - Sync the checkpoint dir files to DFS
   */
  def commit(): Long = {
    val newVersion = loadedVersion + 1
    try {

      logInfo(s"Flushing updates for $newVersion")

      var compactTimeMs = 0L
      var flushTimeMs = 0L
      var checkpointTimeMs = 0L
      if (shouldCreateSnapshot()) {
        // Need to flush the change to disk before creating a checkpoint
        // because rocksdb wal is disabled.
        logInfo(s"Flushing updates for $newVersion")
        flushTimeMs = timeTakenMs { db.flush(flushOptions) }
        if (conf.compactOnCommit) {
          logInfo("Compacting")
          compactTimeMs = timeTakenMs { db.compactRange() }
        }
        checkpointTimeMs = timeTakenMs {
          val checkpointDir = createTempDir("checkpoint")
          logInfo(s"Creating checkpoint for $newVersion in $checkpointDir")
          // Make sure the directory does not exist. Native RocksDB fails if the directory to
          // checkpoint exists.
          Utils.deleteRecursively(checkpointDir)
          // We no longer pause background operation before creating a RocksDB checkpoint because
          // it is unnecessary. The captured snapshot will still be consistent with ongoing
          // background operations.
          val cp = Checkpoint.create(db)
          cp.createCheckpoint(checkpointDir.toString)
          synchronized {
            // if changelog checkpointing is disabled, the snapshot is uploaded synchronously
            // inside the uploadSnapshot() called below.
            // If changelog checkpointing is enabled, snapshot will be uploaded asynchronously
            // during state store maintenance.
            latestSnapshot.foreach(_.close())
            latestSnapshot = Some(
              RocksDBSnapshot(checkpointDir, newVersion, numKeysOnWritingVersion))
            lastSnapshotVersion = newVersion
          }
        }
      }

      logInfo(s"Syncing checkpoint for $newVersion to DFS")
      val fileSyncTimeMs = timeTakenMs {
        if (enableChangelogCheckpointing) {
          try {
            assert(changelogWriter.isDefined)
            changelogWriter.foreach(_.commit())
          } finally {
            changelogWriter = None
          }
        } else {
          assert(changelogWriter.isEmpty)
          uploadSnapshot()
        }
      }

      numKeysOnLoadedVersion = numKeysOnWritingVersion
      loadedVersion = newVersion
      commitLatencyMs ++= Map(
        "flush" -> flushTimeMs,
        "compact" -> compactTimeMs,
        "checkpoint" -> checkpointTimeMs,
        "fileSync" -> fileSyncTimeMs
      )
      logInfo(s"Committed $newVersion, stats = ${metrics.json}")
      loadedVersion
    } catch {
      case t: Throwable =>
        loadedVersion = -1  // invalidate loaded version
        throw t
    } finally {
      // reset resources as either 1) we already pushed the changes and it has been committed or
      // 2) commit has failed and the current version is "invalidated".
      release()
    }
  }

  private def shouldCreateSnapshot(): Boolean = {
    if (enableChangelogCheckpointing) {
      assert(changelogWriter.isDefined)
      val newVersion = loadedVersion + 1
      newVersion - lastSnapshotVersion >= conf.minDeltasForSnapshot ||
        changelogWriter.get.size > 10000
    } else true
  }

  private def uploadSnapshot(): Unit = {
    val localCheckpoint = synchronized {
      val checkpoint = latestSnapshot
      latestSnapshot = None
      checkpoint
    }
    localCheckpoint match {
      case Some(RocksDBSnapshot(localDir, version, numKeys)) =>
        try {
          val uploadTime = timeTakenMs {
            fileManager.saveCheckpointToDfs(localDir, version, numKeys)
            fileManagerMetrics = fileManager.latestSaveCheckpointMetrics
          }
          logInfo(s"$loggingId: Upload snapshot of version $version," +
            s" time taken: $uploadTime ms")
        } finally {
          localCheckpoint.foreach(_.close())
        }
      case _ =>
    }
  }

  /**
   * Drop uncommitted changes, and roll back to previous version.
   */
  def rollback(): Unit = {
    numKeysOnWritingVersion = numKeysOnLoadedVersion
    loadedVersion = -1L
    changelogWriter.foreach(_.abort())
    // Make sure changelogWriter gets recreated next time.
    changelogWriter = None
    release()
    logInfo(s"Rolled back to $loadedVersion")
  }

  def doMaintenance(): Unit = {
    if (enableChangelogCheckpointing) {
      uploadSnapshot()
    }
    val cleanupTime = timeTakenMs {
      fileManager.deleteOldVersions(conf.minVersionsToRetain)
    }
    logInfo(s"Cleaned old data, time taken: $cleanupTime ms")
  }

  /** Release all resources */
  def close(): Unit = {
    try {
      // Acquire DB instance lock and release at the end to allow for synchronized access
      acquire()
      closeDB()

      readOptions.close()
      writeOptions.close()
      flushOptions.close()
      dbOptions.close()
      dbLogger.close()
      synchronized {
        latestSnapshot.foreach(_.close())
      }
      silentDeleteRecursively(localRootDir, "closing RocksDB")
    } catch {
      case e: Exception =>
        logWarning("Error closing RocksDB", e)
    } finally {
      release()
    }
  }

  /** Get the latest version available in the DFS */
  def getLatestVersion(): Long = fileManager.getLatestVersion()

  /** Get the write buffer manager and cache */
  def getWriteBufferManagerAndCache(): (WriteBufferManager, Cache) = (writeBufferManager, lruCache)

  /** Get current instantaneous statistics */
  def metrics: RocksDBMetrics = {
    import HistogramType._
    val totalSSTFilesBytes = getDBProperty("rocksdb.total-sst-files-size")
    val readerMemUsage = getDBProperty("rocksdb.estimate-table-readers-mem")
    val memTableMemUsage = getDBProperty("rocksdb.size-all-mem-tables")
    val blockCacheUsage = getDBProperty("rocksdb.block-cache-usage")
    val pinnedBlocksMemUsage = getDBProperty("rocksdb.block-cache-pinned-usage")
    val nativeOpsHistograms = Seq(
      "get" -> DB_GET,
      "put" -> DB_WRITE,
      "compaction" -> COMPACTION_TIME
    ).toMap
    val nativeOpsLatencyMicros = nativeOpsHistograms.mapValues { typ =>
      RocksDBNativeHistogram(nativeStats.getHistogramData(typ))
    }
    val nativeOpsMetricTickers = Seq(
      /** Number of cache misses that required reading from local disk */
      "readBlockCacheMissCount" -> BLOCK_CACHE_MISS,
      /** Number of cache hits that read data from RocksDB block cache avoiding local disk read */
      "readBlockCacheHitCount" -> BLOCK_CACHE_HIT,
      /** Number of uncompressed bytes read (from memtables/cache/sst) from DB::Get() */
      "totalBytesRead" -> BYTES_READ,
      /** Number of uncompressed bytes issued by DB::{Put(), Delete(), Merge(), Write()} */
      "totalBytesWritten" -> BYTES_WRITTEN,
      /** The number of uncompressed bytes read from an iterator. */
      "totalBytesReadThroughIterator" -> ITER_BYTES_READ,
      /** Duration of writer requiring to wait for compaction or flush to finish. */
      "writerStallDuration" -> STALL_MICROS,
      /** Number of bytes read during compaction */
      "totalBytesReadByCompaction" -> COMPACT_READ_BYTES,
      /** Number of bytes written during compaction */
      "totalBytesWrittenByCompaction" -> COMPACT_WRITE_BYTES,
      /** Number of bytes written during flush */
      "totalBytesWrittenByFlush" -> FLUSH_WRITE_BYTES
    ).toMap
    val nativeOpsMetrics = nativeOpsMetricTickers.mapValues { typ =>
      nativeStats.getTickerCount(typ)
    }

    RocksDBMetrics(
      numKeysOnLoadedVersion,
      numKeysOnWritingVersion,
      readerMemUsage + memTableMemUsage + blockCacheUsage,
      pinnedBlocksMemUsage,
      totalSSTFilesBytes,
      nativeOpsLatencyMicros.toMap,
      commitLatencyMs,
      bytesCopied = fileManagerMetrics.bytesCopied,
      filesCopied = fileManagerMetrics.filesCopied,
      filesReused = fileManagerMetrics.filesReused,
      zipFileBytesUncompressed = fileManagerMetrics.zipFileBytesUncompressed,
      nativeOpsMetrics = nativeOpsMetrics.toMap)
  }

  private def acquire(): Unit = acquireLock.synchronized {
    val newAcquiredThreadInfo = AcquiredThreadInfo()
    val waitStartTime = System.currentTimeMillis
    def timeWaitedMs = System.currentTimeMillis - waitStartTime
    def isAcquiredByDifferentThread = acquiredThreadInfo != null &&
      acquiredThreadInfo.threadRef.get.isDefined &&
      newAcquiredThreadInfo.threadRef.get.get.getId != acquiredThreadInfo.threadRef.get.get.getId

    while (isAcquiredByDifferentThread && timeWaitedMs < conf.lockAcquireTimeoutMs) {
      acquireLock.wait(10)
    }
    if (isAcquiredByDifferentThread) {
      val stackTraceOutput = acquiredThreadInfo.threadRef.get.get.getStackTrace.mkString("\n")
      val msg = s"RocksDB instance could not be acquired by $newAcquiredThreadInfo as it " +
        s"was not released by $acquiredThreadInfo after $timeWaitedMs ms.\n" +
        s"Thread holding the lock has trace: $stackTraceOutput"
      logError(msg)
      throw new IllegalStateException(s"$loggingId: $msg")
    } else {
      acquiredThreadInfo = newAcquiredThreadInfo
      // Add a listener to always release the lock when the task (if active) completes
      Option(TaskContext.get).foreach(_.addTaskCompletionListener[Unit] { _ => this.release() })
      logInfo(s"RocksDB instance was acquired by $acquiredThreadInfo")
    }
  }

  private def release(): Unit = acquireLock.synchronized {
    acquiredThreadInfo = null
    acquireLock.notifyAll()
  }

  private def getDBProperty(property: String): Long = {
    db.getProperty(property).toLong
  }

  private def openDB(): Unit = {
    assert(db == null)
    db = NativeRocksDB.open(dbOptions, workingDir.toString)
    logInfo(s"Opened DB with conf ${conf}")
  }

  private def closeDB(): Unit = {
    if (db != null) {
      db.close()
      db = null
    }
  }

  /** Create a native RocksDB logger that forwards native logs to log4j with correct log levels. */
  private def createLogger(): Logger = {
    val dbLogger = new Logger(dbOptions) {
      override def log(infoLogLevel: InfoLogLevel, logMsg: String) = {
        // Map DB log level to log4j levels
        // Warn is mapped to info because RocksDB warn is too verbose
        // (e.g. dumps non-warning stuff like stats)
        val loggingFunc: ( => String) => Unit = infoLogLevel match {
          case InfoLogLevel.FATAL_LEVEL | InfoLogLevel.ERROR_LEVEL => logError(_)
          case InfoLogLevel.WARN_LEVEL | InfoLogLevel.INFO_LEVEL => logInfo(_)
          case InfoLogLevel.DEBUG_LEVEL => logDebug(_)
          case _ => logTrace(_)
        }
        loggingFunc(s"[NativeRocksDB-${infoLogLevel.getValue}] $logMsg")
      }
    }

    var dbLogLevel = InfoLogLevel.ERROR_LEVEL
    if (log.isWarnEnabled) dbLogLevel = InfoLogLevel.WARN_LEVEL
    if (log.isInfoEnabled) dbLogLevel = InfoLogLevel.INFO_LEVEL
    if (log.isDebugEnabled) dbLogLevel = InfoLogLevel.DEBUG_LEVEL
    dbLogger.setInfoLogLevel(dbLogLevel)
    // The log level set in dbLogger is effective and the one to dbOptions isn't applied to
    // customized logger. We still set it as it might show up in RocksDB config file or logging.
    dbOptions.setInfoLogLevel(dbLogLevel)
    dbOptions.setLogger(dbLogger)
    logInfo(s"Set RocksDB native logging level to $dbLogLevel")
    dbLogger
  }

  /** Create a temp directory inside the local root directory */
  private def createTempDir(prefix: String): File = {
    Utils.createDirectory(localRootDir.getAbsolutePath, prefix)
  }

  /** Attempt to delete recursively, and log the error if any */
  private def silentDeleteRecursively(file: File, msg: String): Unit = {
    try {
      Utils.deleteRecursively(file)
    } catch {
      case e: Exception =>
        logWarning(s"Error recursively deleting local dir $file while $msg", e)
    }
  }

  /** Records the duration of running `body` for the next query progress update. */
  protected def timeTakenMs(body: => Unit): Long = Utils.timeTakenMs(body)._2

  override protected def logName: String = s"${super.logName} $loggingId"
}


/** Mutable and reusable pair of byte arrays */
class ByteArrayPair(var key: Array[Byte] = null, var value: Array[Byte] = null) {
  def set(key: Array[Byte], value: Array[Byte]): ByteArrayPair = {
    this.key = key
    this.value = value
    this
  }
}


/**
 * Configurations for optimizing RocksDB
 * @param compactOnCommit Whether to compact RocksDB data before commit / checkpointing
 */
case class RocksDBConf(
    minVersionsToRetain: Int,
    minDeltasForSnapshot: Int,
    compactOnCommit: Boolean,
    enableChangelogCheckpointing: Boolean,
    blockSizeKB: Long,
    blockCacheSizeMB: Long,
    lockAcquireTimeoutMs: Long,
    resetStatsOnLoad : Boolean,
    formatVersion: Int,
    trackTotalNumberOfRows: Boolean,
    maxOpenFiles: Int,
    writeBufferSizeMB: Long,
    maxWriteBufferNumber: Int,
    boundedMemoryUsage: Boolean,
    totalMemoryUsageMB: Long,
    writeBufferCacheRatio: Double,
    highPriorityPoolRatio: Double,
    compressionCodec: String)

object RocksDBConf {
  /** Common prefix of all confs in SQLConf that affects RocksDB */
  val ROCKSDB_SQL_CONF_NAME_PREFIX = "spark.sql.streaming.stateStore.rocksdb"

  private abstract class ConfEntry(name: String, val default: String) {
    def fullName: String = name.toLowerCase(Locale.ROOT)
  }

  private case class SQLConfEntry(name: String, override val default: String)
    extends ConfEntry(name, default) {

    override def fullName: String =
      s"$ROCKSDB_SQL_CONF_NAME_PREFIX.${name}".toLowerCase(Locale.ROOT)
  }

  private case class ExtraConfEntry(name: String, override val default: String)
    extends ConfEntry(name, default)

  // Configuration that specifies whether to compact the RocksDB data every time data is committed
  private val COMPACT_ON_COMMIT_CONF = SQLConfEntry("compactOnCommit", "false")
  private val ENABLE_CHANGELOG_CHECKPOINTING_CONF = SQLConfEntry(
    "changelogCheckpointing.enabled", "false")
  private val BLOCK_SIZE_KB_CONF = SQLConfEntry("blockSizeKB", "4")
  private val BLOCK_CACHE_SIZE_MB_CONF = SQLConfEntry("blockCacheSizeMB", "8")
  // See SPARK-42794 for details.
  private val LOCK_ACQUIRE_TIMEOUT_MS_CONF = SQLConfEntry("lockAcquireTimeoutMs", "120000")
  private val RESET_STATS_ON_LOAD = SQLConfEntry("resetStatsOnLoad", "true")
  // Config to specify the number of open files that can be used by the DB. Value of -1 means
  // that files opened are always kept open.
  private val MAX_OPEN_FILES_CONF = SQLConfEntry("maxOpenFiles", "-1")
  // Configuration to set the RocksDB format version. When upgrading the RocksDB version in Spark,
  // it may introduce a new table format version that can not be supported by an old RocksDB version
  // used by an old Spark version. Hence, we store the table format version in the checkpoint when
  // a query starts and use it in the entire lifetime of the query. This will ensure the user can
  // still rollback their Spark version for an existing query when RocksDB changes its default
  // table format in a new version. See
  // https://github.com/facebook/rocksdb/wiki/RocksDB-Compatibility-Between-Different-Releases
  // for the RocksDB compatibility guarantee.
  //
  // Note: this is also defined in `SQLConf.STATE_STORE_ROCKSDB_FORMAT_VERSION`. These two
  // places should be updated together.
  private val FORMAT_VERSION = SQLConfEntry("formatVersion", "5")

  // Flag to enable/disable tracking the total number of rows.
  // When this is enabled, this class does additional lookup on write operations (put/delete) to
  // track the changes of total number of rows, which would help observability on state store.
  // The additional lookups bring non-trivial overhead on write-heavy workloads - if your query
  // does lots of writes on state, it would be encouraged to turn off the config and turn on
  // again when you really need the know the number for observability/debuggability.
  private val TRACK_TOTAL_NUMBER_OF_ROWS = SQLConfEntry("trackTotalNumberOfRows", "true")

  // RocksDB Memory Management Related Configurations
  // Configuration to control maximum size of MemTable in RocksDB
  val WRITE_BUFFER_SIZE_MB_CONF_KEY = "writeBufferSizeMB"
  private val WRITE_BUFFER_SIZE_MB_CONF = SQLConfEntry(WRITE_BUFFER_SIZE_MB_CONF_KEY, "-1")

  // Configuration to set maximum number of MemTables in RocksDB, both active and immutable.
  // If the active MemTable fills up and the total number of MemTables is larger than
  // maxWriteBufferNumber, then RocksDB will stall further writes.
  // This may happen if the flush process is slower than the write rate.
  val MAX_WRITE_BUFFER_NUMBER_CONF_KEY = "maxWriteBufferNumber"
  private val MAX_WRITE_BUFFER_NUMBER_CONF = SQLConfEntry(MAX_WRITE_BUFFER_NUMBER_CONF_KEY, "-1")

  // Config to determine whether RocksDB memory usage will be bounded for a given executor
  val BOUNDED_MEMORY_USAGE_CONF_KEY = "boundedMemoryUsage"
  private val BOUNDED_MEMORY_USAGE_CONF = SQLConfEntry(BOUNDED_MEMORY_USAGE_CONF_KEY, "false")

  // Total memory to be occupied by all RocksDB state store instances on this executor
  val MAX_MEMORY_USAGE_MB_CONF_KEY = "maxMemoryUsageMB"
  private val MAX_MEMORY_USAGE_MB_CONF = SQLConfEntry("maxMemoryUsageMB", "500")

  // Memory to be occupied by memtables as part of the cache
  val WRITE_BUFFER_CACHE_RATIO_CONF_KEY = "writeBufferCacheRatio"
  private val WRITE_BUFFER_CACHE_RATIO_CONF = SQLConfEntry(WRITE_BUFFER_CACHE_RATIO_CONF_KEY,
    "0.5")

  // Memory to be occupied by index and filter blocks as part of the cache
  val HIGH_PRIORITY_POOL_RATIO_CONF_KEY = "highPriorityPoolRatio"
  private val HIGH_PRIORITY_POOL_RATIO_CONF = SQLConfEntry(HIGH_PRIORITY_POOL_RATIO_CONF_KEY,
    "0.1")

  def apply(storeConf: StateStoreConf): RocksDBConf = {
    val sqlConfs = CaseInsensitiveMap[String](storeConf.sqlConfs)
    val extraConfs = CaseInsensitiveMap[String](storeConf.extraOptions)

    def getConfigMap(conf: ConfEntry): CaseInsensitiveMap[String] = {
      conf match {
        case _: SQLConfEntry => sqlConfs
        case _: ExtraConfEntry => extraConfs
      }
    }

    def getBooleanConf(conf: ConfEntry): Boolean = {
      Try { getConfigMap(conf).getOrElse(conf.fullName, conf.default).toBoolean } getOrElse {
        throw new IllegalArgumentException(s"Invalid value for '${conf.fullName}', must be boolean")
      }
    }

    def getIntConf(conf: ConfEntry): Int = {
      Try { getConfigMap(conf).getOrElse(conf.fullName, conf.default).toInt } getOrElse {
        throw new IllegalArgumentException(s"Invalid value for '${conf.fullName}', " +
          "must be an integer")
      }
    }

    def getRatioConf(conf: ConfEntry): Double = {
      Try {
        getConfigMap(conf).getOrElse(conf.fullName, conf.default).toDouble
      } filter { config => config >= 0.0 && config <= 1.0 } getOrElse {
        throw new IllegalArgumentException(s"Invalid value for '${conf.fullName}', " +
          "must be a ratio between 0.0 and 1.0")
      }
    }

    def getLongConf(conf: ConfEntry): Long = {
      Try { getConfigMap(conf).getOrElse(conf.fullName, conf.default).toLong } getOrElse {
        throw new IllegalArgumentException(
          s"Invalid value for '${conf.fullName}', must be a long"
        )
      }
    }

    def getPositiveLongConf(conf: ConfEntry): Long = {
      Try {
        getConfigMap(conf).getOrElse(conf.fullName, conf.default).toLong
      } filter { _ >= 0 } getOrElse {
        throw new IllegalArgumentException(
          s"Invalid value for '${conf.fullName}', must be a positive integer")
      }
    }

    def getPositiveIntConf(conf: ConfEntry): Int = {
      Try {
        getConfigMap(conf).getOrElse(conf.fullName, conf.default).toInt
      } filter { _ >= 0 } getOrElse {
        throw new IllegalArgumentException(
          s"Invalid value for '${conf.fullName}', must be a positive integer")
      }
    }

    RocksDBConf(
      storeConf.minVersionsToRetain,
      storeConf.minDeltasForSnapshot,
      getBooleanConf(COMPACT_ON_COMMIT_CONF),
      getBooleanConf(ENABLE_CHANGELOG_CHECKPOINTING_CONF),
      getPositiveLongConf(BLOCK_SIZE_KB_CONF),
      getPositiveLongConf(BLOCK_CACHE_SIZE_MB_CONF),
      getPositiveLongConf(LOCK_ACQUIRE_TIMEOUT_MS_CONF),
      getBooleanConf(RESET_STATS_ON_LOAD),
      getPositiveIntConf(FORMAT_VERSION),
      getBooleanConf(TRACK_TOTAL_NUMBER_OF_ROWS),
      getIntConf(MAX_OPEN_FILES_CONF),
      getLongConf(WRITE_BUFFER_SIZE_MB_CONF),
      getIntConf(MAX_WRITE_BUFFER_NUMBER_CONF),
      getBooleanConf(BOUNDED_MEMORY_USAGE_CONF),
      getLongConf(MAX_MEMORY_USAGE_MB_CONF),
      getRatioConf(WRITE_BUFFER_CACHE_RATIO_CONF),
      getRatioConf(HIGH_PRIORITY_POOL_RATIO_CONF),
      storeConf.compressionCodec)
  }

  def apply(): RocksDBConf = apply(new StateStoreConf())
}

/** Class to represent stats from each commit. */
case class RocksDBMetrics(
    numCommittedKeys: Long,
    numUncommittedKeys: Long,
    totalMemUsageBytes: Long,
    pinnedBlocksMemUsage: Long,
    totalSSTFilesBytes: Long,
    nativeOpsHistograms: Map[String, RocksDBNativeHistogram],
    lastCommitLatencyMs: Map[String, Long],
    filesCopied: Long,
    bytesCopied: Long,
    filesReused: Long,
    zipFileBytesUncompressed: Option[Long],
    nativeOpsMetrics: Map[String, Long]) {
  def json: String = Serialization.write(this)(RocksDBMetrics.format)
}

object RocksDBMetrics {
  val format = Serialization.formats(NoTypeHints)
}

/** Class to wrap RocksDB's native histogram */
case class RocksDBNativeHistogram(
    sum: Long, avg: Double, stddev: Double, median: Double, p95: Double, p99: Double, count: Long) {
  def json: String = Serialization.write(this)(RocksDBMetrics.format)
}

object RocksDBNativeHistogram {
  def apply(nativeHist: HistogramData): RocksDBNativeHistogram = {
    RocksDBNativeHistogram(
      nativeHist.getSum,
      nativeHist.getAverage,
      nativeHist.getStandardDeviation,
      nativeHist.getMedian,
      nativeHist.getPercentile95,
      nativeHist.getPercentile99,
      nativeHist.getCount)
  }
}

case class AcquiredThreadInfo() {
  val threadRef: WeakReference[Thread] = new WeakReference[Thread](Thread.currentThread())
  val tc: TaskContext = TaskContext.get()

  override def toString(): String = {
    val taskStr = if (tc != null) {
      val taskDetails =
        s"partition ${tc.partitionId}.${tc.attemptNumber} in stage " +
          s"${tc.stageId}.${tc.stageAttemptNumber()}, TID ${tc.taskAttemptId}"
      s", task: $taskDetails"
    } else ""

    s"[ThreadId: ${threadRef.get.map(_.getId)}$taskStr]"
  }
}

