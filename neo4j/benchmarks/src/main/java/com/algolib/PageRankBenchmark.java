
/**************************************************
 *
 * file: PageRank.java
 *
 * @Author:   Iacovos G. Kolokasis
 * @Version:  21-08-2024
 * @email:    kolokasis@ics.forth.gr
 *
 * @brief PageRank benchmark that uses Neo4j Graph Data Science
 *
 **************************************************/

package com.algolib;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.config.Configurator;
import org.apache.logging.log4j.core.config.builder.api.ConfigurationBuilderFactory;
import org.apache.logging.log4j.core.config.builder.api.ConfigurationBuilder;
import org.apache.logging.log4j.core.config.builder.impl.BuiltConfiguration;
import org.apache.logging.log4j.core.config.builder.api.AppenderComponentBuilder;
import org.apache.logging.log4j.core.config.builder.api.RootLoggerComponentBuilder;
import org.neo4j.dbms.api.DatabaseManagementService;
import org.neo4j.dbms.api.DatabaseManagementServiceBuilder;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Transaction;
import org.neo4j.graphdb.Result;
import org.neo4j.configuration.GraphDatabaseSettings;
import org.neo4j.kernel.internal.GraphDatabaseAPI;
import org.neo4j.kernel.api.procedure.GlobalProcedures;
import org.neo4j.gds.pagerank.PageRankWriteProc;
import org.neo4j.common.DependencyResolver;                                                                          
import org.neo4j.gds.procedures.*;
import org.neo4j.graphdb.config.Setting;
import org.neo4j.gds.procedures.GraphDataScience;
import org.neo4j.gds.catalog.GraphProjectProc;


import java.lang.reflect.Field;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.HashMap;
import java.util.List;  // <-- Import this to resolve the List symbol


import static org.neo4j.configuration.GraphDatabaseSettings.DEFAULT_DATABASE_NAME;

public class PageRankBenchmark {

  private static final Logger logger = LogManager.getLogger(PageRankBenchmark.class);

  // Set the path to your embedded Neo4j database directory
  private static final Path DATABASE_DIRECTORY = Paths.get("/mnt/spark/intermediate/cit-Patents/database");

  // Define the writeProperty, maxIterations, and dampingFactor for PageRank algorithm
  private static final String PAGERANK = "pagerankScore"; // Property to store PageRank scores
  private static final int MAX_ITERATIONS = 20; // Maximum iterations for PageRank
  private static final float DAMPING_FACTOR = 0.85f; // Damping factor for PageRank

  static {
    configureLogging();
  }

  private static void configureLogging() {
    ConfigurationBuilder<BuiltConfiguration> builder = ConfigurationBuilderFactory.newConfigurationBuilder();

    // Configure the Console appender
    AppenderComponentBuilder consoleAppender = builder.newAppender("Console", "CONSOLE")
    .addAttribute("target", "SYSTEM_OUT");
    consoleAppender.add(builder.newLayout("PatternLayout")
      .addAttribute("pattern", "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"));
    builder.add(consoleAppender);

    // Configure the root logger
    RootLoggerComponentBuilder rootLogger = builder.newRootLogger(org.apache.logging.log4j.Level.INFO);
    rootLogger.add(builder.newAppenderRef("Console"));
    builder.add(rootLogger);

    // Apply the configuration
    Configurator.initialize(builder.build());
  }

  public static void main(String[] args) {
    logger.info("Starting the PageRank benchmark...");

    // Initialize the embedded database management service
    DatabaseManagementService managementService = new DatabaseManagementServiceBuilder(DATABASE_DIRECTORY)
    .setConfig(GraphDatabaseSettings.procedure_allowlist, List.of("apoc.coll.*,apoc.load.*,gds.*"))
    .setConfig(GraphDatabaseSettings.procedure_unrestricted, List.of("apoc.coll.*,apoc.load.*,gds.*"))
    .build();

    GraphDatabaseService graphDb = managementService.database(DEFAULT_DATABASE_NAME);

    // Register a shutdown hook to cleanly shut down the database when JVM exits
    Runtime.getRuntime().addShutdownHook(new Thread(() -> managementService.shutdown()));

    // Register the GraphListProc procedure
    registerProcedures(graphDb, GraphProjectProc.class, PageRankWriteProc.class);

    try (Transaction tx = graphDb.beginTx()) {
      final String load_query = "CALL gds.graph.project(\n" +
      "    'myGraph',\n" +
      "    '*',  // Include all node labels\n" +
      "    '*'  // Include all relationship types\n" +
      ")\n" +
      "YIELD graphName, nodeCount, relationshipCount;";

      Result result = tx.execute(load_query);

      // Verify if the graph was created successfully
      if (result.hasNext()) {
        System.out.println("Graph created successfully: " + result.next());
      }

      // Start the benchmark timer
      long startTime = System.currentTimeMillis();

      final String query = "CALL gds.pageRank.write('myGraph', {\n" +
      "  maxIterations: 10,\n" +
      "  dampingFactor: 0.85,\n" +
      "  writeProperty: 'pagerank'\n" +
      "})\n" +
      "YIELD nodePropertiesWritten AS writtenProperties, ranIterations;";

      result = tx.execute(query);

      //// Print the results
      while (result.hasNext()) {
        Map<String, Object> row = result.next(); // Work directly with the Map returned
        System.out.println(row);
      }

      // End the benchmark timer
      long endTime = System.currentTimeMillis();
      System.out.println("PageRank execution time: " + (endTime - startTime) + "ms");

      // Commit the transaction
      tx.commit();
    } finally {
      // Shutdown the database management service
      managementService.shutdown();
    }

    logger.info("PageRank benchmark completed.");
  }

  private static void registerProcedures(GraphDatabaseService graphDb, Class<?>... procedures) {
    GraphDatabaseAPI graphDatabaseAPI = (GraphDatabaseAPI) graphDb;
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
}
