/*
 * Adapted from Lucene demo
 * 
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Comparator;
import java.util.Date;
import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.analysis.core.SimpleAnalyzer;
import org.apache.lucene.analysis.core.WhitespaceAnalyzer;
import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.codecs.Codec;
import org.apache.lucene.demo.knn.DemoEmbeddings;
import org.apache.lucene.demo.knn.KnnVectorDict;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;
import org.apache.lucene.document.TextField;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.IndexReader;
import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.index.IndexWriterConfig;
import org.apache.lucene.index.MergePolicy;
import org.apache.lucene.index.NoMergePolicy;
import org.apache.lucene.index.IndexWriterConfig.OpenMode;
import org.apache.lucene.index.Term;
import org.apache.lucene.index.TieredMergePolicy;
import org.apache.lucene.store.Directory;
import org.apache.lucene.store.FSDirectory;
import org.apache.lucene.util.IOUtils;
import org.apache.lucene.document.IntField;

/**
 * Index all text files in a newline seperated document
 *
 * <p>This is a command-line application demonstrating simple Lucene indexing. Run it with no
 * command-line arguments for usage information.
 */
public class IndexFiles implements AutoCloseable {
  static final String KNN_DICT = "knn-dict";

  // Calculates embedding vectors for KnnVector search
  private final DemoEmbeddings demoEmbeddings;
  private final KnnVectorDict vectorDict;

  private IndexFiles(KnnVectorDict vectorDict) throws IOException {
    if (vectorDict != null) {
      this.vectorDict = vectorDict;
      demoEmbeddings = new DemoEmbeddings(vectorDict);
    } else {
      this.vectorDict = null;
      demoEmbeddings = null;
    }
  }

  /** Index all text files in a newline seperated document. */
  public static void main(String[] args) throws Exception {
    String usage =
        "java org.apache.lucene.demo.IndexFiles"
            + " -i INDEX_PATH -d DOCS [-u] [-k DICT_PATH] [-de] [-rb RBSIZE] [-fm] [-dam] [-a ANALYZER] [-die] [-ws WARMUP_SETS] [-hrl]\n\n"
            + "This indexes the newline seperated docs in the file DOCS, creating a Lucene index"
            + "in INDEX_PATH that can be searched with SearchFiles\n"
            + "IF DICT_PATH contains a KnnVector dictionary, the index will also support KnnVector search";
    String indexPath = "index";
    String docsPath = null;
    String vectorDictSource = null;
    Analyzer analyzer = new StandardAnalyzer();
    boolean create = true;
    boolean disable_encryption = false;
    boolean force_merge = false;
    boolean disable_automatic_merging = false;
    boolean delete_if_existing = false;
    boolean hard_ram_limit = false;
    double ram_buffer_size = 128.0; // default
    int warmup_sets = 0;
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case "-index", "-i":
          indexPath = args[++i];
          break;
        case "-docs", "-d":
          docsPath = args[++i];
          break;
        case "-knn_dict", "-k":
          vectorDictSource = args[++i]; // this option likely won't be used but is kept for legacy reasons
          break;
        case "-update", "-u":
          create = false;
          break;
        case "-create", "-c":
          create = true;
          break;
        case "-disable_enc", "-de":
          disable_encryption = true;
          break;
        case "-rb_size", "-rb":
          ram_buffer_size = Double.parseDouble(args[++i]);
          break;
        case "-force_merge", "-fm":
          force_merge = true;
          break;
        case "-disable_automatic_merging", "-dam":
          disable_automatic_merging = true;
          break;
        case "-analyser", "-a":
          switch(args[++i]) {
            case "st", "standard" -> { analyzer = new StandardAnalyzer(); }
            case "si", "simple" -> { analyzer = new SimpleAnalyzer(); }
            case "wh", "whitespace" -> { analyzer = new WhitespaceAnalyzer(); }
            default -> { throw new IllegalArgumentException("unknown analyzer " + args[i]); }
          }
          break;
        case "-delete_if_existing", "-die":
          delete_if_existing = true;
          break;
        case "-warmup_sets", "-ws":
          warmup_sets = Integer.parseInt(args[++i]);
          break;
        case "-hard-ram-limit", "-hrl":
          hard_ram_limit = true;
          break;
        default:
          throw new IllegalArgumentException("unknown parameter " + args[i]);
      }
    }

    if (docsPath == null) {
      System.err.println("Usage: " + usage);
      System.exit(1);
    }

    final Path docDir = Paths.get(docsPath);
    if (!Files.isReadable(docDir)) {
      System.out.println(
          "Document directory '"
              + docDir.toAbsolutePath()
              + "' does not exist or is not readable, please check the path");
      System.exit(1);
    }

    // everything is wrapped in a try/catch to terminate with message in case of IO exception
    try {
      // ---------------- RUN WARMUP SETS ------------------

      // use a different index path so as to not affect a possible existing index
      String warmupIndexPath = indexPath + "-warmup";
      for (int i = 1; i <= warmup_sets; i++) {
        IndexWriterConfig iwc = buildIwc(analyzer, create, ram_buffer_size, disable_encryption, disable_automatic_merging, hard_ram_limit);
        indexFiles(warmupIndexPath, docDir, iwc, true, force_merge, vectorDictSource, i, disable_automatic_merging);
        // delete warmup index again
        deleteDirectoryIfExists(warmupIndexPath);
      }

      // ---------------- RUN ACTUAL SETS -------------------
      IndexWriterConfig iwc = buildIwc(analyzer, create, ram_buffer_size, disable_encryption, disable_automatic_merging, hard_ram_limit);
      indexFiles(indexPath, docDir, iwc, delete_if_existing, force_merge, vectorDictSource, -1, disable_automatic_merging);
      
    } catch (IOException e) {
      System.out.println(" caught a " + e.getClass() + "\n with message: " + e.getMessage());
    }
  }

  /** Helper function for building the IndexWriterConfig for each run. This is because the same IWC cannot be reused
   * for different IndexWriters, so a new one has to be created each run.
   * 
   * @param analyzer
   * @param create
   * @param ram_buffer_size
   * @param disable_encryption
   * @param disable_automatic_merging
   * @param hard_ram_limit
   * @return
   */

  static IndexWriterConfig buildIwc(Analyzer analyzer,
                                    boolean create, 
                                    double ram_buffer_size, 
                                    boolean disable_encryption,
                                    boolean disable_automatic_merging,
                                    boolean hard_ram_limit) {
    IndexWriterConfig iwc = new IndexWriterConfig(analyzer);

    if (create) {
      // Create a new index in the directory, removing any
      // previously indexed documents:
      iwc.setOpenMode(OpenMode.CREATE);
    } else {
      // Add new documents to an existing index:
      iwc.setOpenMode(OpenMode.CREATE_OR_APPEND);
    }

    // Optional: for better indexing performance, if you
    // are indexing m any documents, increase the RAM
    // buffer.  But if you do this, increase the max heap
    // size to the JVM (eg add -Xmx512m or -Xmx1g):
    //
    if (hard_ram_limit) iwc.setRAMPerThreadHardLimitMB((int) ram_buffer_size);
    else iwc.setRAMBufferSizeMB(ram_buffer_size);

    // Force commit to be done manually so we can time it seperately
    iwc.setCommitOnClose(false);

    if (disable_encryption) {
      iwc.setCodec(Codec.forName("NoCompressionCodec"));
    }
	
    if (disable_automatic_merging) {
      iwc.setMergePolicy(NoMergePolicy.INSTANCE);
    }

    return iwc;
  }

  /** Actually runs the indexer (pulled into a function to make running warmup runs easier)
   * 
   * @param indexPath
   * @param docDir
   * @param iwc
   * @param delete_if_existing
   * @param force_merge
   * @param vectorDictSource
   * @param warmup_no -1 if this is the actual run
   * @param disable_automatic_merging
   * @throws IOException
   */

  static void indexFiles(String indexPath,
                         Path docDir,
                         IndexWriterConfig iwc,
                         boolean delete_if_existing, 
                         boolean force_merge,
                         String vectorDictSource,
                         int warmup_no,
                         boolean disable_automatic_merging) throws IOException {

    // initialise timer variables
    long timeToManuallyMergeNs =  0;
    long timeToCommitNs = 0;
    long timeToFlushNs = 0;
    long totalTimeNs = 0;
    long totalGCtimeMs = 0;

    if (delete_if_existing) {
      deleteDirectoryIfExists(indexPath);
    }

    Directory dir = FSDirectory.open(Paths.get(indexPath));

    KnnVectorDict vectorDictInstance = null;
    long vectorDictSize = 0;
    if (vectorDictSource != null) {
      KnnVectorDict.build(Paths.get(vectorDictSource), dir, KNN_DICT);
      vectorDictInstance = new KnnVectorDict(dir, KNN_DICT);
      vectorDictSize = vectorDictInstance.ramBytesUsed();
    }
    
    // start timing indexing here
    long start = System.nanoTime();
    long startGCtime = getGCRuntime();

    try (IndexWriterTrackFlushing writer = new IndexWriterTrackFlushing(dir, iwc);
        IndexFiles indexFiles = new IndexFiles(vectorDictInstance)) {
      indexFiles.indexDocs(writer, docDir);

      // NOTE: if you want to maximize search performance,
      // you can optionally call forceMerge here.  This can be
      // a terribly costly operation, so generally it's only
      // worth it when your index is relatively static (ie
      // you're done adding documents to it):
      long startMerge = System.nanoTime();
      if (force_merge) {
        if (disable_automatic_merging) {
          // need to change the merge policy back to one that allows merges because NoMergePolicy isn't bypassed
          // by forceMerge (which internally still calls maybeMerge)
          writer.getConfig().setMergePolicy(new TieredMergePolicy());
        }
        writer.forceMerge(1); 
      }
      long endMerge = System.nanoTime();
      timeToManuallyMergeNs = endMerge - startMerge;

      // manually commit
      long startCommit = System.nanoTime();
      writer.commit();
      long endCommit = System.nanoTime();
      timeToCommitNs = endCommit - startCommit;

      timeToFlushNs = writer.getTimeSpentFlushing();
    } finally {
      IOUtils.close(vectorDictInstance);
    }

    try (IndexReader reader = DirectoryReader.open(dir)) {
      // don't end timing until opening the indexReader because it can trigger another index flush
      long end = System.nanoTime();
      long endGCTime = getGCRuntime();
      totalTimeNs = end - start;
      totalGCtimeMs = endGCTime - startGCtime;

      if (warmup_no < 0) 
        System.out.println(String.format("Actual run: Indexed %d documents in %d ms", reader.numDocs(), totalTimeNs/1000000));
      else 
        System.out.println(String.format("Warmup set %d: Indexed %d documents in %d ms", warmup_no, reader.numDocs(), totalTimeNs/1000000));
      System.out.println(String.format("Indexing xput: %.2f docs/s", ((float) reader.numDocs())/(((float) totalTimeNs)/1000000000)));
      System.out.println("Breakdown: ");
      System.out.println(String.format("Flushing: %d ms", timeToFlushNs/1000000));
      System.out.println(String.format("Committing: %d ms", timeToCommitNs/1000000));
      System.out.println(String.format("Manual merge: %d ms", timeToManuallyMergeNs/1000000));
      System.out.println(String.format("GC time: %d ms", totalGCtimeMs));
      System.out.println(String.format("All other (presumably ingesting): %d ms", (totalTimeNs - timeToFlushNs - timeToCommitNs - timeToManuallyMergeNs)/1000000 - totalGCtimeMs));
      System.out.println(String.format(" %d documents in %d ms", reader.numDocs(), totalTimeNs/1000000));
      if (warmup_no > 0) System.out.println();

      if (vectorDictInstance != null
          && reader.numDocs() > 100
          && vectorDictSize < 1_000_000
          && System.getProperty("smoketester") == null) {
        throw new RuntimeException(
            "Are you (ab)using the toy vector dictionary? See the package javadocs to understand why you got this exception.");
      }
    }
  }

  /**
   * Indexes each line in the given file as a doc
   * 
   * @param writer Writer to the index where the given file/dir info will be stored
   * @param path The file whose lines to index
   * @throws IOException If there is a low-level I/O error
   */
  void indexDocs(final IndexWriter writer, Path path) throws IOException {
    if (demoEmbeddings != null) {
      System.out.println("knnvector not supported; skipping indexing");
    }
    else if (Files.isDirectory(path)) {
      throw new IOException("Doc path cannot be a directory");
    } else {
      try (BufferedReader reader = Files.newBufferedReader(path, StandardCharsets.ISO_8859_1)) {
        int DID = 0; // note: lucene documents are assigned an internal doc id which may not correspond with this one

        String docContent = reader.readLine();
        while (docContent != null) {
          Document doc = new Document();

          doc.add(new IntField("DID", DID, Field.Store.YES));
          doc.add(new TextField("contents", docContent, Field.Store.NO));

          if (writer.getConfig().getOpenMode() == OpenMode.CREATE) {
            // New index, so we just add the document (no old document can be there):
            //System.out.println("adding document id " + Integer.toString(DID));
            writer.addDocument(doc);
          } else {
            // Existing index (an old copy of this document may have been indexed) so
            // we use updateDocument instead to replace the old one matching the exact
            // path, if present:
            //System.out.println("updating document id " + Integer.toString(DID));
            writer.updateDocument(new Term("DID", Integer.toString(DID)), doc);
          }

          DID++;
          docContent = reader.readLine();
        }

      } catch (IOException e) {
        System.out.println("IO exception occurred: " + e.toString());
      }
    }
  }

  @Override
  public void close() throws IOException {
    IOUtils.close(vectorDict);
  }

  /** Helper function: deletes directory if it exists
   * 
   * @param name name of directory to delete
   * @throws IOException
   */
  static void deleteDirectoryIfExists(String name) throws IOException {
    Path pathToBeDeleted = Paths.get(name);

    if (Files.exists(pathToBeDeleted)) {
      //System.out.println("Index directory already exists; deleting");
      Files.walk(pathToBeDeleted)
        .sorted(Comparator.reverseOrder())
        .map(Path::toFile)
        .forEach(File::delete);
      //System.out.println("Deleted index directory");
    }
  }

  /** Helper function: returns total GC runtime up until the point that this fn was called in ms
   * Credit: https://stackoverflow.com/questions/13915357/measuring-time-spent-on-gc 
   * 
   * @return
   */

  static long getGCRuntime() {
      long collectionTime = 0;
      for (GarbageCollectorMXBean garbageCollectorMXBean : ManagementFactory.getGarbageCollectorMXBeans()) {
          collectionTime += garbageCollectorMXBean.getCollectionTime();
      }
      return collectionTime;
  }


  // custom IndexWriter that tracks total time spent on flushing
  // notes:
  // - tracking completely breaks if using multiple indexer threads
  // - if multiple calls to doBeforeFlush occur before doAfterFlush, the latest is used
  // - if a call to doAfterFlush occurs with no doBefore right before, it is ignored
  static class IndexWriterTrackFlushing extends IndexWriter {
    long timeSpentFlushing = 0;
    long start = -1;

    IndexWriterTrackFlushing(Directory dir, IndexWriterConfig iwc) throws IOException {
      super(dir, iwc);
    }

    @Override
    protected void doBeforeFlush() {
      //System.out.println("Do before flush called");
      start = System.nanoTime();
    }

    @Override
    protected void doAfterFlush() {
      //System.out.println("Do after flush called");
      if (start != -1) {
        timeSpentFlushing += System.nanoTime() - start;
        start = -1;
      }
    }

    long getTimeSpentFlushing() {
      return timeSpentFlushing;
    }
  }
}
