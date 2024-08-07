// evaluates the list of newline seperated queries given in a document on the specified index

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileSystems;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.concurrent.*;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.concurrent.CountDownLatch;

import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.lucene.index.DirectoryReader;
import org.apache.lucene.index.LeafReaderContext;
import org.apache.lucene.index.Term;
import org.apache.lucene.queryparser.classic.QueryParser;
import org.apache.lucene.search.BooleanClause;
import org.apache.lucene.search.BooleanQuery;
import org.apache.lucene.search.Collector;
import org.apache.lucene.search.ConstantScoreQuery;
import org.apache.lucene.search.IndexSearcher;
import org.apache.lucene.search.Query;
import org.apache.lucene.search.ScoreDoc;
import org.apache.lucene.search.ScoreMode;
import org.apache.lucene.search.Scorer;
import org.apache.lucene.search.SimpleCollector;
import org.apache.lucene.search.TermQuery;
import org.apache.lucene.search.TopDocs;
import org.apache.lucene.search.TotalHits;
import org.apache.lucene.search.Weight;
import org.apache.lucene.store.FSDirectory;
import org.apache.lucene.search.LRUQueryCache;
import org.apache.lucene.search.QueryCachingPolicy;
import org.apache.lucene.search.FuzzyQuery;
import org.apache.lucene.search.UsageTrackingQueryCachingPolicy;


public class PhaseMultiThreadedEvaluateQueries {
  private static void exit(String msg) {
    System.out.println(msg);
    System.exit(0);
  }

  public static void main(String[] args) throws Exception {
    // get arguments
    String usage = "java EvaluateQueries -q QUERY_PATH -i INDEX_PATH [-r RESULTS_PATH] [-n N_RESULTS] [-ds] [-ar] [-dc] [-ws WARMUP_SETS]";

    String queriesFile = null;
    String indexDir = null;
    String resultsFile = null;
    int noOfResults = 10; // note: has no effect if scoring is disabled
    // (could fix that in future if i figure out how to make collectors terminate search early)
    boolean disableScoring = false;
    int warmupSets = 0;
    boolean disableCache = false;
    boolean reportTailLatency = false;
    boolean mxWorkload = false;

    // note: this method is not robust enough to handle missing options after arguments, but it's what
    // IndexFiles uses
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case "-q", "-queries" -> queriesFile = args[++i];
        case "-i", "-index" -> indexDir = args[++i];
        case "-r", "-results" -> resultsFile = args[++i];
        case "-n", "-nresults" -> noOfResults = Integer.parseInt(args[++i]);
        case "-ds", "-disable_scoring" -> disableScoring = true;
        case "-ar", "-all_results" -> noOfResults = Integer.MAX_VALUE;
        case "-ws", "-warmup_sets" -> warmupSets = Integer.parseInt(args[++i]);
        case "-dc", "-disable_cache" -> disableCache = true;
        case "-rl", "-report_latency" -> reportTailLatency = true;
        case "-mx", "-mix_results" -> mxWorkload = true;
        default -> { exit("Unrecognized argument " + args[i] + ". Usage: " + usage); }
      }
    }

    if (queriesFile == null || indexDir == null) { exit("Queries file or index dir not specified! Usage: " + usage); }

    // open index
    long heapSizeBeforeOpening = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
    DirectoryReader reader = DirectoryReader.open(FSDirectory.open(Paths.get(indexDir)));
    long heapSizeAfterOpening = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
    System.out.println("Size of uncompressed index: " + (heapSizeAfterOpening - heapSizeBeforeOpening));

    LRUQueryCache queryCache = new LRUQueryCache(40000, 1 * 1024 * 1024 * 1024); // 10,000 queries, 100MB cache size

    IndexSearcher searcher = new IndexSearcher(reader);
    if (disableCache) {
      searcher.setQueryCache(null);
    } else {
      searcher.setQueryCache(queryCache);
    }

    // open results file
    BufferedWriter resultsWriter = null;
    if (resultsFile != null) {
      resultsWriter = new BufferedWriter(new FileWriter(resultsFile, StandardCharsets.ISO_8859_1));
    }

    System.out.println("Number of indexed docs to search: " + reader.numDocs());
    System.out.println("Evaluating the queries in file '" + queriesFile + "'");

    // run some sets to warm up the JVM
    for (int i = 1; i <= warmupSets; i++) {
      long start = System.nanoTime();
      // disable writing results to file here
      int qNo = evalQueries(queriesFile, searcher, null, disableScoring, noOfResults, reportTailLatency, mxWorkload);
      long end = System.nanoTime();

      long timeMs = (end - start)/1000000;

      System.out.println(String.format("Warmup set %d: Searched %d queries in %d ms, QPS %.2f", i, qNo, timeMs, ((float) qNo)/(((float) timeMs)/1000)));
    }

    // run the actual run

    long GCruntimeBefore = getGCRuntime();
    long start = System.nanoTime();
    int qNo = evalQueries(queriesFile, searcher, resultsWriter, disableScoring, noOfResults, reportTailLatency, mxWorkload);
    long end = System.nanoTime();
    long GCruntimeAfter = getGCRuntime();

    System.out.println("Total GC runtime: " + getGCRuntime() + " ms");
    System.out.println("GC runtime during the actual run: " + (GCruntimeAfter - GCruntimeBefore) + " ms");

    long timeMs = (end - start)/1000000;

    System.out.println(String.format("Actual run: Searched %d queries in %d ms, QPS %.2f", qNo, timeMs, ((float) qNo)/(((float) timeMs)/1000)));

    // cleanup
    reader.close();
    if (resultsFile!= null) {
      resultsWriter.flush();
      resultsWriter.close();
    }
  }

  // helper fn
  static int evalQueries(String queriesFile, 
    IndexSearcher searcher, 
    BufferedWriter resultsWriter, 
    boolean disableScoring,
    int noOfResults,
    boolean reportTailLatency,
    boolean mxWorkload) throws IOException {

    // Create a thread pool
    ExecutorService executorService = Executors.newFixedThreadPool(32);

    // open query file
    BufferedReader queriesReader = new BufferedReader(new FileReader(queriesFile, StandardCharsets.ISO_8859_1));

    // Map to store execution times
    ConcurrentHashMap<Integer, Long> queryExecutionTimes = new ConcurrentHashMap<>();

    String query;
    int qNo = 1;
    int totalQueries = 40000;
    int queriesPerBatch = 20000;

    int queries70Percent = (int) Math.ceil(0 * queriesPerBatch);
    int queries20Percent = (int) Math.ceil(1 * queriesPerBatch);
    int queries10Percent = queriesPerBatch - queries70Percent - queries20Percent;
          
    int boundary70 = queries70Percent;
    int boundary90 = boundary70 + queries20Percent;
    
    while ((query = queriesReader.readLine()) != null && qNo <= totalQueries) {
      CountDownLatch latchCase0 = new CountDownLatch(queries70Percent);
      CountDownLatch latchCase1 = new CountDownLatch(queries20Percent);
      for (int i = 0; i < queriesPerBatch && query != null; i++) {
        final String currentQuery = query;
        final int currentQNo = qNo;

        executorService.submit(() -> {
          long startTime = 0;
          if (reportTailLatency) {
            startTime = System.currentTimeMillis();
          }

          try {
            if (currentQNo % queriesPerBatch <= boundary70) {
              // First 70% of queries
              evalQuery(currentQuery, currentQNo, searcher, resultsWriter, disableScoring, 50);
              latchCase0.countDown();
            } else if (currentQNo % queriesPerBatch <= boundary90) {
              // Next 20% of queries
              latchCase0.await();
              evalQuery(currentQuery, currentQNo, searcher, resultsWriter, disableScoring, 320000);
              latchCase1.countDown();
            } else {
              // Remaining 10% of queries
              latchCase1.await();
              evalQuery(currentQuery, currentQNo, searcher, resultsWriter, disableScoring, 100);
            }
          } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            e.printStackTrace();
          } finally {
            if (reportTailLatency) {
              long endTime = System.currentTimeMillis();
              long duration = endTime - startTime;
              queryExecutionTimes.put(currentQNo, duration);
            }
          }
        });
        qNo++;
        query = queriesReader.readLine();
      }
    }


    queriesReader.close();
    // Shut down the executor service and wait for tasks to complete
    executorService.shutdown();
    try {
      executorService.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
    } catch (InterruptedException e) {
      e.printStackTrace();
      Thread.currentThread().interrupt(); // Preserve interrupt status
    }

    if (reportTailLatency) {
      // Calculate tail latency
      List<Long> latencies = new ArrayList<>(queryExecutionTimes.values());
      Collections.sort(latencies);

      // Assuming you want the 99th percentile tail latency
      int index100thPercentile = (int) (latencies.size());
      int index99thPercentile = (int) (latencies.size() * 0.99);
      int index95thPercentile = (int) (latencies.size() * 0.95);

      long tailLatency = latencies.get(index100thPercentile - 1);
      System.out.println("100th percentile tail latency: " + tailLatency + " milliseconds");
      
      tailLatency = latencies.get(index99thPercentile - 1);
      System.out.println("99th percentile tail latency: " + tailLatency + " milliseconds");
      
      tailLatency = latencies.get(index95thPercentile - 1);
      System.out.println("95th percentile tail latency: " + tailLatency + " milliseconds");
    }

    return qNo - 1;
  }

  // helper fn
  static void evalQuery(String query, 
    int qNo,
    IndexSearcher searcher, 
    BufferedWriter resultsWriter,
    boolean disableScoring,
    int noOfResults) throws IOException {
    // build the query
    BooleanQuery.Builder b = new BooleanQuery.Builder();

    for (String term : query.split(" ")) {
      b.add(new BooleanClause(new TermQuery(new Term("contents", term)), BooleanClause.Occur.MUST));
    }

    Query q = b.build();

    // System.out.println("Query is " + q.toString("contents"));

    if (disableScoring) {
      // note: there is also the option of wrapping the query in ConstantScoreQuery, but that
      // did not result in much of a decrease of latency and it is thought still leads to a lot of
      // ranking/scoring operations occurring behind the scenes
      UnscoredCollector c = new UnscoredCollector();
      searcher.search(q, c);

      // System.out.println(String.format("Query number %d: %d hits\n", qNo, c.docIds.size()));

      if (resultsWriter != null) {
        resultsWriter.write(String.format("Query number %d: %d hits\n", qNo, c.docIds.size()));
        for (int did : c.docIds) {
          resultsWriter.write(String.format("Document %d\n", did));
        }
        resultsWriter.write("\n");
      }
    }
    else {
      TopDocs results = searcher.search(q, noOfResults);

      // if (results.totalHits.relation == TotalHits.Relation.GREATER_THAN_OR_EQUAL_TO) {
      //     System.out.println(String.format("Query number %d: more than %d hits\n", qNo, results.totalHits.value));
      // } else {
      //     System.out.println(String.format("Query number %d: %d hits\n", qNo, results.totalHits.value));
      // }

      // if results file is not null, print the results to file
      if (resultsWriter != null) {
        //if (results.totalHits.relation == TotalHits.Relation.GREATER_THAN_OR_EQUAL_TO) {
        //  resultsWriter.write(String.format("Query number %d: more than %d hits\n", qNo, results.totalHits.value));
        //} else {
        //  resultsWriter.write(String.format("Query number %d: %d hits\n", qNo, results.totalHits.value));
        //}
        for (ScoreDoc r : results.scoreDocs) {
          //resultsWriter.write(String.format("Document %d, score %.2f\n", Integer.parseInt(searcher.storedFields().document(r.doc).get("DID")), r.score));
          int documentId = Integer.parseInt(searcher.storedFields().document(r.doc).get("DID")); 
          float documentScore = r.score;

          searcher.storedFields().document(r.doc).get("did");
        }
        //resultsWriter.write("\n");
      }
    }
  }

  // returns total GC runtime up until the point that this fn was called
  // credit: https://stackoverflow.com/questions/13915357/measuring-time-spent-on-gc 
  static long getGCRuntime() {
    long collectionTime = 0;
    for (GarbageCollectorMXBean garbageCollectorMXBean : ManagementFactory.getGarbageCollectorMXBeans()) {
      collectionTime += garbageCollectorMXBean.getCollectionTime();
    }
    return collectionTime;
  }

  // credit: second answer to 
  // https://stackoverflow.com/questions/22744858/lucene-completely-disable-weighting-scoring-ranking
  // (adjusted for Lucene 9.6.0)
  public static class UnscoredCollector extends SimpleCollector {
    public final List<Integer> docIds = new ArrayList<>();
    private LeafReaderContext currentLeafReaderContext;

    @Override
    protected void doSetNextReader(LeafReaderContext context) throws IOException {
      this.currentLeafReaderContext = context;
    }

    @Override
    public void setWeight(Weight weight) {}

    @Override
    public ScoreMode scoreMode() {
      return ScoreMode.COMPLETE_NO_SCORES;
    }

    @Override
    public void collect(int localDocId) {
      docIds.add(currentLeafReaderContext.docBase + localDocId);
    }
  }
}

