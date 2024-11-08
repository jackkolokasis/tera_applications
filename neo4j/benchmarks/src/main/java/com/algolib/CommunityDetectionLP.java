/**************************************************
 *
 * file: CommunityDetectionLP.java
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
import org.neo4j.gds.catalog.GraphProjectProc;
import org.neo4j.gds.labelpropagation.LabelPropagationMutateProc;

public class CommunityDetectionLP extends GraphAlgorithm {

  // Constructor
  public CommunityDetectionLP(GraphDatabaseService graphDb) {
    super(graphDb, GraphProjectProc.class, LabelPropagationMutateProc.class);
  }

  @Override
  public void run() {
    System.out.println("Running cdlp algorithm...");

    // Start the benchmark timer
    long startTime = System.currentTimeMillis();
      
    final String query = "CALL gds.labelPropagation.mutate('myGraph', {\n" +
    "  maxIterations: 10,\n" +
    "  mutateProperty: 'community'\n" +
    "})\n" +
    "YIELD communityCount, ranIterations;";

    Result result = tx.execute(query);
      
    while (result.hasNext()) {
      Map<String, Object> row = result.next(); // Work directly with the Map returned
      System.out.println(row);
    }

    // End the benchmark timer
    long endTime = System.currentTimeMillis();
    System.out.println("Cdlp execution time: " + (endTime - startTime) + "ms");
      
    // Commit the transaction
    tx.commit();
  }
}
