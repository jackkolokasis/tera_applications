
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
import org.neo4j.configuration.GraphDatabaseSettings;

import java.nio.file.Paths;
import java.util.List;  // <-- Import this to resolve the List symbol


import static org.neo4j.configuration.GraphDatabaseSettings.DEFAULT_DATABASE_NAME;

public class BenchmarkRunner {

  private static String algo = null;
  private static String databasePath = null;
  private static final Logger logger = LogManager.getLogger(BenchmarkRunner.class);

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

  public static void parseRuntimeArguments(String[] args) {
    // Iterate through the command-line arguments
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {

        case "--algo":
          if (i + 1 >= args.length) {
            System.err.println("No value provided for --algo.");
            return;
          }

          String algoValue = args[++i];
          if (!("pr".equals(algoValue) || "wcc".equals(algoValue) || "cdlp".equals(algoValue) || "bfs".equals(algoValue) || "sssp".equals(algoValue))) {
            System.err.println("Invalid value for --algo. Accepted values are 'pr' or 'wcc'.");
            return;
          }

          algo = algoValue;
          break;

        case "--database_path":
          if (i + 1 >= args.length) {
            System.err.println("No value provided for --database_path.");
            return;
          }
            
          databasePath = args[++i];
          break;

        default:
        System.err.println("Unknown argument: " + args[i]);
        return;
      }
    }

    // Check if both required flags are provided
    if (algo == null || databasePath == null) {
      System.err.println("Both --algo and --database_path must be provided.");
      return;
    }
  }

  public static void main(String[] args) {
    logger.info("Starting the BenchmarkRunner");

    // Parse the runtime arguments
    parseRuntimeArguments(args);

    logger.info("Starting the PageRank benchmark...");

    // Initialize the embedded database management service
    System.out.println(databasePath);
    DatabaseManagementService managementService = new DatabaseManagementServiceBuilder(Paths.get(databasePath))
    .setConfig(GraphDatabaseSettings.pagecache_memory, 1073741824L)
    .setConfig(GraphDatabaseSettings.procedure_allowlist, List.of("apoc.coll.*,apoc.load.*,gds.*"))
    .setConfig(GraphDatabaseSettings.procedure_unrestricted, List.of("apoc.coll.*,apoc.load.*,gds.*"))
    .build();

    System.out.print(DEFAULT_DATABASE_NAME);
    GraphDatabaseService graphDb = managementService.database(DEFAULT_DATABASE_NAME);

    // Register a shutdown hook to cleanly shut down the database when JVM exits
    Runtime.getRuntime().addShutdownHook(new Thread(() -> managementService.shutdown()));
        
    GraphAlgorithm benchmark = null;

    switch (algo) {
      case "pr":
        benchmark = new PageRank(graphDb);
        break;

      case "cdlp":
        benchmark = new CommunityDetectionLP(graphDb);
        break;

      case "wcc":
        benchmark = new WeaklyConnectedComponent(graphDb);
        break;

      case "bfs":
        benchmark = new BreadthFirstSearch(graphDb);
        break;

      case "sssp":
        benchmark = new SingleSourceShortestPath(graphDb);
        break;
    }
        
    benchmark.run();
  }
}
