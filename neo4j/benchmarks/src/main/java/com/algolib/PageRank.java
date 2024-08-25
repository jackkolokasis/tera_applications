/**************************************************
 *
 * file: PageRank.java
 *
 * @Author:   Iacovos G. Kolokasis
 * @Version:  25-08-2024
 * @email:    kolokasis@ics.forth.gr
 *
 **************************************************/

package com.algolib;
import java.util.Map;

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Result;
import org.neo4j.gds.pagerank.PageRankWriteProc;
import org.neo4j.gds.catalog.GraphProjectProc;

public class PageRank extends GraphAlgorithm {

  // Constructor
  public PageRank(GraphDatabaseService graphDb) {
    super(graphDb, GraphProjectProc.class, PageRankWriteProc.class);
  }

  @Override
  public void run() {
    System.out.println("Running PageRank algorithm...");

    // Start the benchmark timer
    long startTime = System.currentTimeMillis();
      
    final String query = "CALL gds.pageRank.write('myGraph', {\n" +
    "  maxIterations: 10,\n" +
    "  dampingFactor: 0.85,\n" +
    "  writeProperty: 'pagerank'\n" +
    "})\n" +
    "YIELD nodePropertiesWritten AS writtenProperties, ranIterations;";

    Result result = tx.execute(query);
      
    while (result.hasNext()) {
      Map<String, Object> row = result.next(); // Work directly with the Map returned
      System.out.println(row);
    }

    // End the benchmark timer
    long endTime = System.currentTimeMillis();
    System.out.println("PageRank execution time: " + (endTime - startTime) + "ms");
      
    // Commit the transaction
    tx.commit();
  }
}
