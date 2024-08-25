/**************************************************
 *
 * file: GraphAlgorithm.java
 *
 * @Author:   Iacovos G. Kolokasis
 * @Version:  24-08-2024
 * @email:    kolokasis@ics.forth.gr
 *
 **************************************************/

package com.algolib;

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.kernel.internal.GraphDatabaseAPI;
import org.neo4j.kernel.api.procedure.GlobalProcedures;
import org.neo4j.graphdb.Transaction;
import org.neo4j.graphdb.Result;

public abstract class GraphAlgorithm {

  protected GraphDatabaseService graphDB;
  protected Transaction tx;

  public GraphAlgorithm(GraphDatabaseService graphDB, Class<?>... procedures) {
    this.graphDB = graphDB;
    registerProcedures(procedures);

    this.tx = this.graphDB.beginTx();
    graphProject();
  }

  // Concrete method to be inherited by subclasses
  public void graphProject() {
    System.out.println("Executing graph project common functionality...");

    long startTime = System.currentTimeMillis();

    final String command = "CALL gds.graph.project(\n" +
    "    'myGraph',\n" +
    "    '*',\n" +
    "    '*'\n" +
    ")\n" +
    "YIELD graphName, nodeCount, relationshipCount;";

    Result result = tx.execute(command);
      
    // Verify if the graph was created successfully
    if (result.hasNext()) {
      System.out.println("Graph created successfully: " + result.next());
    }

    long endTime = System.currentTimeMillis();
    System.out.println("Graph projection execution time: " + (endTime - startTime) + "ms");
  }


  public void registerProcedures(Class<?>... procedures) {
    GraphDatabaseAPI graphDatabaseAPI = (GraphDatabaseAPI) graphDB;
    GlobalProcedures globalProceduresService = graphDatabaseAPI.getDependencyResolver().resolveDependency(GlobalProcedures.class);

    for (Class<?> procedure : procedures) {
      try {
        globalProceduresService.registerProcedure(procedure);
        globalProceduresService.registerFunction(procedure);
      } catch (Exception e) {
        throw new RuntimeException("Error registering procedure: " + procedure.getName(), e);
      }
    }
  }

  // Abstract method to be implemented by subclasses
  public abstract void run();
}
