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

public class MultiTenantEvaluateQueries {
  public static final int LARGE_QUERIES = 500000;
  public static final int MIX_QUERY_THREADS = 16;
  public static final int THREADS_PER_QUERY_TYPE = 16;

  private static void exit(String msg) {
    System.out.println(msg);
    System.exit(0);
  }

  public static void main(String[] args) throws Exception {
    // get arguments
    String usage = "java EvaluateQueries -q QUERY_PATH -i INDEX_PATH [-r RESULTS_PATH] [-n N_RESULTS] [-ds] [-ar] [-dc]";

    List<String> queriesFile = new ArrayList<>();
    String indexDir = null;
    List<Integer> noOfResults = new ArrayList<>();
    boolean disableCache = false;
    List<Integer> nqValues = new ArrayList<>();
    List<Integer> mxTypeQueries = new ArrayList<>();

    // note: this method is not robust enough to handle missing options after arguments, but it's what
    // IndexFiles uses
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case "-q", "-queries" -> queriesFile.add(args[++i]);
        case "-i", "-index" -> indexDir = args[++i];
        case "-n", "-nresults" -> noOfResults.add(Integer.parseInt(args[++i]));
        case "-dc", "-disable_cache" -> disableCache = true;
        case "-nq", "-num_queries" -> nqValues.add(Integer.parseInt(args[++i]));
        case "-mxq", "-num_mix_type_queries" -> mxTypeQueries.add(Integer.parseInt(args[++i]));
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

    System.out.println("Number of indexed docs to search: " + reader.numDocs());
    System.out.println("Evaluating the queries in file '" + queriesFile + "'");

    long GCruntimeBefore = getGCRuntime();
    long start = System.nanoTime();

    String[] queriesFiles = {"queriesFile1.txt", "queriesFile2.txt", "queriesFile3.txt", "queriesFile4.txt", "queriesFile5.txt"};
    // Map to store execution times
    ConcurrentHashMap<Integer, Long> queryExecutionTimes = new ConcurrentHashMap<>();
    // Array to keep track of threads
    EvalQueriesTask[] tasks = new EvalQueriesTask[queriesFile.size() - 1];
    EvalMixQueriesTask mxQueriesTask = null; 
    int startQueryNo = 1; 
    int totalResults = nqValues.get(0);

    // Create and start 5 threads
    for (int i = 0; i < queriesFile.size(); i++) {
      if (i > 0) {
        startQueryNo = totalResults + 1; 
        totalResults += nqValues.get(i);
      }

      if (i == queriesFile.size() - 1) {
        mxQueriesTask = new EvalMixQueriesTask(queriesFile.get(i), searcher,
          mxTypeQueries, queryExecutionTimes, startQueryNo, MIX_QUERY_THREADS);
        mxQueriesTask.start();
        continue;
      }
        
      tasks[i] = new EvalQueriesTask(queriesFile.get(i), searcher,
        noOfResults.get(i), queryExecutionTimes, startQueryNo, THREADS_PER_QUERY_TYPE);
      tasks[i].start();
    }

    // Wait for all threads to finish
    for (int i = 0; i < queriesFile.size() - 1; i++) {
      try {
        tasks[i].join();
      } catch (InterruptedException e) {
        e.printStackTrace();
      }
    }

    mxQueriesTask.join();

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

    long end = System.nanoTime();
    long GCruntimeAfter = getGCRuntime();

    System.out.println("Total GC runtime: " + getGCRuntime() + " ms");
    System.out.println("GC runtime during the actual run: " + (GCruntimeAfter - GCruntimeBefore) + " ms");

    long timeMs = (end - start)/1000000;
    System.out.println(String.format("Actual run: Searched %d queries in %d ms, QPS %.2f", totalResults, timeMs, ((float) totalResults)/(((float) timeMs)/1000)));

    // cleanup
    reader.close();
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
}
  
