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

package org.apache.spark.sql.streaming

import java.util.UUID
import java.util.concurrent.{ConcurrentHashMap, ConcurrentMap}

import scala.collection.JavaConverters._

import com.google.protobuf.ByteString

import org.apache.spark.annotation.Evolving
import org.apache.spark.connect.proto.Command
import org.apache.spark.connect.proto.StreamingQueryManagerCommand
import org.apache.spark.connect.proto.StreamingQueryManagerCommandResult
import org.apache.spark.internal.Logging
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.connect.common.{InvalidPlanInput, StreamingListenerPacket}
import org.apache.spark.util.SparkSerDeUtils

/**
 * A class to manage all the [[StreamingQuery]] active in a `SparkSession`.
 *
 * @since 3.5.0
 */
@Evolving
class StreamingQueryManager private[sql] (sparkSession: SparkSession) extends Logging {

  // Mapping from id to StreamingQueryListener. There's another mapping from id to
  // StreamingQueryListener on server side. This is used by removeListener() to find the id
  // of previously added StreamingQueryListener and pass it to server side to find the
  // corresponding listener on server side. We use id to StreamingQueryListener mapping
  // here to make sure there's no hash collision as well as handling the case that adds and
  // removes the same listener instance multiple times properly.
  private lazy val listenerCache: ConcurrentMap[String, StreamingQueryListener] =
    new ConcurrentHashMap()

  /**
   * Returns a list of active queries associated with this SQLContext
   *
   * @since 3.5.0
   */
  def active: Array[StreamingQuery] = {
    executeManagerCmd(_.setActive(true)).getActive.getActiveQueriesList.asScala.map { q =>
      RemoteStreamingQuery.fromStreamingQueryInstanceResponse(sparkSession, q)
    }.toArray
  }

  /**
   * Returns the query if there is an active query with the given id, or null.
   *
   * @since 3.5.0
   */
  def get(id: UUID): StreamingQuery = get(id.toString)

  /**
   * Returns the query if there is an active query with the given id, or null.
   *
   * @since 3.5.0
   */
  def get(id: String): StreamingQuery = {
    val response = executeManagerCmd(_.setGetQuery(id))
    if (response.hasQuery) {
      RemoteStreamingQuery.fromStreamingQueryInstanceResponse(sparkSession, response.getQuery)
    } else {
      null
    }
  }

  /**
   * Wait until any of the queries on the associated SQLContext has terminated since the creation
   * of the context, or since `resetTerminated()` was called. If any query was terminated with an
   * exception, then the exception will be thrown.
   *
   * If a query has terminated, then subsequent calls to `awaitAnyTermination()` will either
   * return immediately (if the query was terminated by `query.stop()`), or throw the exception
   * immediately (if the query was terminated with exception). Use `resetTerminated()` to clear
   * past terminations and wait for new terminations.
   *
   * For correctly documenting exceptions across multiple queries, users need to stop all of them
   * after any of them terminates with exception, and then check the `query.exception()` for each
   * query.
   *
   * @since 3.5.0
   */
  // TODO(SPARK-43299): verity the behavior of this method after JVM client-side error-handling
  // framework is supported and modify the doc accordingly.
  def awaitAnyTermination(): Unit = {
    executeManagerCmd(_.getAwaitAnyTerminationBuilder.build())
  }

  /**
   * Wait until any of the queries on the associated SQLContext has terminated since the creation
   * of the context, or since `resetTerminated()` was called. Returns whether any query has
   * terminated or not (multiple may have terminated). If any query has terminated with an
   * exception, then the exception will be thrown.
   *
   * If a query has terminated, then subsequent calls to `awaitAnyTermination()` will either
   * return `true` immediately (if the query was terminated by `query.stop()`), or throw the
   * exception immediately (if the query was terminated with exception). Use `resetTerminated()`
   * to clear past terminations and wait for new terminations.
   *
   * For correctly documenting exceptions across multiple queries, users need to stop all of them
   * after any of them terminates with exception, and then check the `query.exception()` for each
   * query.
   *
   * @since 3.5.0
   */
  // TODO(SPARK-43299): verity the behavior of this method after JVM client-side error-handling
  // framework is supported and modify the doc accordingly.
  def awaitAnyTermination(timeoutMs: Long): Boolean = {
    require(timeoutMs > 0, "Timeout has to be positive")
    executeManagerCmd(
      _.getAwaitAnyTerminationBuilder.setTimeoutMs(
        timeoutMs)).getAwaitAnyTermination.getTerminated
  }

  /**
   * Forget about past terminated queries so that `awaitAnyTermination()` can be used again to
   * wait for new terminations.
   *
   * @since 3.5.0
   */
  def resetTerminated(): Unit = {
    executeManagerCmd(_.setResetTerminated(true))
  }

  /**
   * Register a [[StreamingQueryListener]] to receive up-calls for life cycle events of
   * [[StreamingQuery]].
   *
   * @since 3.5.0
   */
  def addListener(listener: StreamingQueryListener): Unit = {
    // TODO: [SPARK-44400] Improve the Listener to provide users a way to access the Spark session
    //  and perform arbitrary actions inside the Listener. Right now users can use
    //  `val spark = SparkSession.builder.getOrCreate()` to create a Spark session inside the
    //  Listener, but this is a legacy session instead of a connect remote session.
    val id = UUID.randomUUID.toString
    cacheListenerById(id, listener)
    executeManagerCmd(
      _.getAddListenerBuilder
        .setListenerPayload(ByteString.copyFrom(SparkSerDeUtils
          .serialize(StreamingListenerPacket(id, listener))))
        .setId(id))
  }

  /**
   * Deregister a [[StreamingQueryListener]].
   *
   * @since 3.5.0
   */
  def removeListener(listener: StreamingQueryListener): Unit = {
    val id = getIdByListener(listener)
    executeManagerCmd(
      _.getRemoveListenerBuilder
        .setId(id))
    removeCachedListener(id)
  }

  /**
   * List all [[StreamingQueryListener]]s attached to this [[StreamingQueryManager]].
   *
   * @since 3.5.0
   */
  def listListeners(): Array[StreamingQueryListener] = {
    executeManagerCmd(_.setListListeners(true)).getListListeners.getListenerIdsList.asScala
      .filter(listenerCache.containsKey(_))
      .map(listenerCache.get(_))
      .toArray
  }

  private def executeManagerCmd(
      setCmdFn: StreamingQueryManagerCommand.Builder => Unit // Sets the command field, like stop().
  ): StreamingQueryManagerCommandResult = {

    val cmdBuilder = Command.newBuilder()
    val managerCmdBuilder = cmdBuilder.getStreamingQueryManagerCommandBuilder

    // Set command.
    setCmdFn(managerCmdBuilder)

    val resp = sparkSession.execute(cmdBuilder.build()).head

    if (!resp.hasStreamingQueryManagerCommandResult) {
      throw new RuntimeException(
        "Unexpected missing response for streaming query manager command")
    }

    resp.getStreamingQueryManagerCommandResult
  }

  private def cacheListenerById(id: String, listener: StreamingQueryListener): Unit = {
    listenerCache.putIfAbsent(id, listener)
  }

  private def getIdByListener(listener: StreamingQueryListener): String = {
    listenerCache.forEach((k, v) => if (listener.equals(v)) return k)
    throw InvalidPlanInput(s"No id with listener $listener is found.")
  }

  private def removeCachedListener(id: String): StreamingQueryListener = {
    listenerCache.remove(id)
  }
}
