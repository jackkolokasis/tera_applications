/**************************************************
 *
 * file: WeaklyConnectedComponent.java
 *
 * @Author:   Iacovos G. Kolokasis
 * @Version:  25-08-2024
 * @email:    kolokasis@ics.forth.gr
 *
 **************************************************/

package com.algolib;

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Result;
import org.neo4j.gds.catalog.GraphProjectProc;
import org.neo4j.gds.wcc.WccWriteProc;
import java.util.Map;

public class WeaklyConnectedComponent extends GraphAlgorithm {

  // Constructor
  public WeaklyConnectedComponent(GraphDatabaseService graphDb) {
    super(graphDb, GraphProjectProc.class, WccWriteProc.class);
  }

  @Override
  public void run() {
    System.out.println("Running WeaklyConnectedComponent algorithm...");

    // Start the benchmark timer
    long startTime = System.currentTimeMillis();
      
    final String query = "CALL gds.wcc.write('myGraph', {\n" +
    "  writeProperty: 'component'\n" +
    "})\n" +
    "YIELD nodePropertiesWritten AS writtenProperties, componentCount;";

    Result result = tx.execute(query);
      
    while (result.hasNext()) {
      Map<String, Object> row = result.next(); // Work directly with the Map returned
      System.out.println(row);
    }

    // End the benchmark timer
    long endTime = System.currentTimeMillis();
    System.out.println("WCC execution time: " + (endTime - startTime) + "ms");
      
    // Commit the transaction
    tx.commit();
  }
}
