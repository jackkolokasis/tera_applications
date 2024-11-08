
/**************************************************
 *
 * file: SingleSourceShortestPath.java
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
import org.neo4j.gds.paths.singlesource.dijkstra.AllShortestPathsDijkstraMutateProc;

import java.util.Map;

public class SingleSourceShortestPath extends GraphAlgorithm {

  // Constructor
  public SingleSourceShortestPath(GraphDatabaseService graphDb) {
    super(graphDb, GraphProjectProc.class, AllShortestPathsDijkstraMutateProc.class);
  }

  @Override
  public void run() {
    System.out.println("Running SSSP algorithm...");

    // Start the benchmark timer
    long startTime = System.currentTimeMillis();

    final String query = "MATCH (source:VID {VID: 6})" +
    "CALL gds.allShortestPaths.dijkstra.mutate('myGraph', {\n" +
    "   sourceNode: id(source),\n" +
    "   mutateRelationshipType: 'PATH'\n" +
    "})\n" +
    "YIELD relationshipsWritten\n" +
    "RETURN relationshipsWritten";

    Result result = tx.execute(query);

    while (result.hasNext()) {
      Map<String, Object> row = result.next();
      Long relationshipsWritten = (Long) row.get("relationshipsWritten");
      System.out.println("Relationships Written: " + relationshipsWritten);
    }

    // End the benchmark timer
    long endTime = System.currentTimeMillis();
    System.out.println("SSSP algorithm execution time: " + (endTime - startTime) + "ms");
      
    // Commit the transaction
    tx.commit();
  }
}
