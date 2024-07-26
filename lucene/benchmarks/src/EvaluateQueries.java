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


public class EvaluateQueries {
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
    List<Integer> nqValues = new ArrayList<>();


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
        case "-nq" -> nqValues.add(Integer.parseInt(args[++i]));
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
      int qNo = evalQueries(queriesFile, searcher, null, disableScoring, noOfResults, nqValues);
      long end = System.nanoTime();

      long timeMs = (end - start)/1000000;

      System.out.println(String.format("Warmup set %d: Searched %d queries in %d ms, QPS %.2f", i, qNo, timeMs, ((float) qNo)/(((float) timeMs)/1000)));
    }

    // run the actual run

    long GCruntimeBefore = getGCRuntime();
    long start = System.nanoTime();
    int qNo = evalQueries(queriesFile, searcher, resultsWriter, disableScoring, noOfResults, nqValues);
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
    List<Integer> nqValues) throws IOException {

    // Create a thread pool
    ExecutorService executorService = Executors.newFixedThreadPool(32);
    // Open query file
    BufferedReader queriesReader = new BufferedReader(new FileReader(queriesFile, StandardCharsets.ISO_8859_1));
    // Map to store execution times
    ConcurrentHashMap<Integer, Long> queryExecutionTimes = new ConcurrentHashMap<>();

    String query;
    int qNo = 1;
    
    while ((query = queriesReader.readLine()) != null) {
      final String currentQuery = query;
      final int currentQNo = qNo;

      executorService.submit(() -> {
        long startTime = System.currentTimeMillis();
        final int currentNumResults = determineResultLimit(nqValues, currentQNo);

        try {
            evalQuery(currentQuery, currentQNo, searcher, resultsWriter, disableScoring, currentNumResults);
        } catch (IOException e) {
          Thread.currentThread().interrupt();
          e.printStackTrace();
        } finally {
          long endTime = System.currentTimeMillis();
          long duration = endTime - startTime;
          if (currentNumResults == 50) {
            queryExecutionTimes.put(currentQNo, duration);
          }
        }
      });
      qNo++;
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

    // Calculate tail latency
    List<Long> latencies = new ArrayList<>(queryExecutionTimes.values());
    Collections.sort(latencies);

    // Assuming you want the 99th percentile tail latency
    int index99thPercentile = (int) (latencies.size() * 0.99);
    int index95thPercentile = (int) (latencies.size() * 0.95);

    long tailLatency = latencies.get(index99thPercentile - 1);
    System.out.println("99th percentile tail latency: " + tailLatency + " milliseconds");

    tailLatency = latencies.get(index95thPercentile - 1);
    System.out.println("95th percentile tail latency: " + tailLatency + " milliseconds");

    return qNo - 1;
  }

  private static int determineResultLimit(List<Integer> nqValues, int currentQNo) {
    int firstThreshold = nqValues.get(0);
    int secondThreshold = firstThreshold + nqValues.get(1);
    int thirdThreshold = secondThreshold + nqValues.get(2);
    int fourthThreshold = thirdThreshold + nqValues.get(3);

    if (currentQNo <= firstThreshold) {
      return 50;
    }

    if (currentQNo <= secondThreshold) {
      return 500000;
    } 

    if (currentQNo <= thirdThreshold) {
      return 50;
    } 

    if (currentQNo <= fourthThreshold) {
     return 500000;
    }

    return 50;
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

      // if results file is not null, print the results to file
      if (resultsWriter != null) {
        for (ScoreDoc r : results.scoreDocs) {
          int documentId = Integer.parseInt(searcher.storedFields().document(r.doc).get("DID")); 
          float documentScore = r.score;

          searcher.storedFields().document(r.doc).get("did");
        }
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

