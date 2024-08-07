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

public class EvalMixQueriesTask extends Thread {
  private String qFile;
  private IndexSearcher search;
  private List<Integer> numTypeQueries;
  private ConcurrentHashMap<Integer, Long> qTime;
  private int startQueryNo;
  private int numWorkers;

  // Constructor to initialize all the parameters
  public EvalMixQueriesTask(String queriesFile, IndexSearcher searcher,
                         List<Integer> numTypeQueries,
                         ConcurrentHashMap<Integer, Long> qExecTimes,
                         int startQueryNo, int numWorkers) {
    this.qFile = queriesFile;
    this.search = searcher;
    this.numTypeQueries = numTypeQueries;
    this.qTime = qExecTimes;
    this.startQueryNo = startQueryNo;
    this.numWorkers = numWorkers;
  }
  
  private int determineResultLimit(int currentQNo) {
    int firstThreshold = this.numTypeQueries.get(0) + this.startQueryNo;
    int secondThreshold = firstThreshold + this.numTypeQueries.get(1);
    int thirdThreshold = secondThreshold + this.numTypeQueries.get(2);
    int fourthThreshold = thirdThreshold + this.numTypeQueries.get(3);

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

  @Override
  // Override the run method to call evalQueries
  public void run() {
    try {
      System.out.println("Run query: " + qFile);
      evalQueries(qFile, search, qTime, startQueryNo, numWorkers);
    } catch (IOException e) {
      Thread.currentThread().interrupt();
      e.printStackTrace();
    }
  }

  // helper fn
  public void evalQueries(String queriesFile,
                          IndexSearcher searcher, 
                          ConcurrentHashMap<Integer, Long> queryExecutionTimes,
                          int startQNo,
                          int numWorkers) throws IOException {

    // Create a thread pool
    ExecutorService executorService = Executors.newFixedThreadPool(numWorkers);
    // Open query file
    BufferedReader queriesReader = new BufferedReader(new FileReader(queriesFile, StandardCharsets.ISO_8859_1));

    String query;
    int qNo = startQNo;
    
    while ((query = queriesReader.readLine()) != null) {
      final String currentQuery = query;
      final int currentQNo = qNo;

      executorService.submit(() -> {
        final int currentNumResults = determineResultLimit(currentQNo);
        try {
          evalQuery(currentQuery, currentQNo, searcher, currentNumResults, queryExecutionTimes);
        } catch (IOException e) {
          Thread.currentThread().interrupt();
          e.printStackTrace();
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
  }

  // helper fn
  static void evalQuery(String query, 
                        int qNo,
                        IndexSearcher searcher, 
                        int noOfResults,
                        ConcurrentHashMap<Integer, Long> queryExecutionTimes) throws IOException {

    long startTime = System.currentTimeMillis();

    // build the query
    BooleanQuery.Builder b = new BooleanQuery.Builder();

    for (String term : query.split(" ")) {
      b.add(new BooleanClause(new TermQuery(new Term("contents", term)), BooleanClause.Occur.MUST));
    }

    Query q = b.build();
    TopDocs results = searcher.search(q, noOfResults);

    for (ScoreDoc r : results.scoreDocs) {
      int documentId = Integer.parseInt(searcher.storedFields().document(r.doc).get("DID")); 
      float documentScore = r.score;

      searcher.storedFields().document(r.doc).get("did");
    }

    long endTime = System.currentTimeMillis();
    long duration = endTime - startTime;
    if (noOfResults == 50) {
      queryExecutionTimes.put(qNo, duration);
    }
  }

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
