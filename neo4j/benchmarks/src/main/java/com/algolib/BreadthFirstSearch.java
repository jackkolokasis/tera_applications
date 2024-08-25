/**************************************************
 *
 * file: BreadthFirstSearch.java
 *
 * @Author:   Iacovos G. Kolokasis
 * @Version:  25-08-2024
 * @email:    kolokasis@ics.forth.gr
 *
 * @brief
 *
 **************************************************/

package com.algolib;

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Result;
import org.neo4j.gds.catalog.GraphProjectProc;
import org.neo4j.gds.paths.traverse.BfsStreamProc;

public class BreadthFirstSearch extends GraphAlgorithm {

  // Constructor
  public BreadthFirstSearch(GraphDatabaseService graphDb) {
    super(graphDb, GraphProjectProc.class, BfsStreamProc.class);
  }

  @Override
  public void run() {
    System.out.println("Running Breadth First Search algorithm...");

    // Start the benchmark timer
    long startTime = System.currentTimeMillis();

    final String query = "MATCH (source:VID {VID: 6009541})" +
    "CALL gds.bfs.stream('myGraph', {\n" +
    "   sourceNode: id(source)\n" +
    "})\n" +
    "YIELD path\n" +
    "RETURN path";

    Result result = tx.execute(query);

    while (!result.hasNext()) {
      System.out.println("Queryr Error!! No results!!");
    }

    // End the benchmark timer
    long endTime = System.currentTimeMillis();
    System.out.println("Breadth First Search algorithm execution time: " + (endTime - startTime) + "ms");
      
    // Commit the transaction
    tx.commit();
  }
}
