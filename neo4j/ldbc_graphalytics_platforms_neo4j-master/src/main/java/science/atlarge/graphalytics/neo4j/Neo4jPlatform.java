/*
 * Copyright 2015 Delft University of Technology
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package science.atlarge.graphalytics.neo4j;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import science.atlarge.graphalytics.domain.algorithms.Algorithm;
import science.atlarge.graphalytics.domain.benchmark.BenchmarkRun;
import science.atlarge.graphalytics.domain.graph.FormattedGraph;
import science.atlarge.graphalytics.domain.graph.LoadedGraph;
import science.atlarge.graphalytics.execution.*;
import science.atlarge.graphalytics.neo4j.metrics.AbstractNeo4jJobFactory;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgolibNeo4jJobFactory;
import science.atlarge.graphalytics.neo4j.metrics.embedded.EmbeddedNeo4jJobFactory;
import science.atlarge.graphalytics.report.result.BenchmarkMetrics;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Neo4j platform driver for the Graphalytics benchmark.
 *
 * @author Gábor Szárnyas
 * @author Bálint Hegyi
 */
public class Neo4jPlatform implements Platform {

	protected static final Logger LOG = LogManager.getLogger();
	private static final String PLATFORM_NAME = "neo4j";

	public Neo4jLoader loader;

	@Override
	public void verifySetup() { }

	@Override
	public LoadedGraph loadGraph(FormattedGraph formattedGraph) throws Exception {
		Neo4jConfiguration platformConfig = Neo4jConfiguration.parsePropertiesFile();
		loader = new Neo4jLoader(formattedGraph, platformConfig);

		LOG.info("Loading graph " + formattedGraph.getName());
		Path loadedPath = Paths.get("/mnt/spark/intermediate").resolve(formattedGraph.getName());
		LOG.info("Jack Kolokasis Path " + loadedPath);

		try {

			int exitCode = loader.load(loadedPath.toString());
			if (exitCode != 0) {
				throw new PlatformExecutionException("Neo4j exited with an error code: " + exitCode);
			}
		} catch (Exception e) {
			throw new PlatformExecutionException("Failed to load a Neo4j dataset.", e);
		}
		LOG.info("Loaded graph " + formattedGraph.getName());

		Path databasePath = loadedPath.resolve("database");
		return new LoadedGraph(formattedGraph, databasePath.toString());
	}

	@Override
	public void deleteGraph(LoadedGraph loadedGraph) throws Exception {
		LOG.info("Unloading graph " + loadedGraph.getFormattedGraph().getName());
		try {

			int exitCode = loader.unload(loadedGraph.getLoadedPath());
			if (exitCode != 0) {
				throw new PlatformExecutionException("Neo4j exited with an error code: " + exitCode);
			}
		} catch (Exception e) {
			throw new PlatformExecutionException("Failed to unload a Neo4j dataset.", e);
		}
		LOG.info("Unloaded graph " +  loadedGraph.getFormattedGraph().getName());
	}

	@Override
	public void prepare(RunSpecification runSpecification) { }

	@Override
	public void startup(RunSpecification runSpecification) {
		BenchmarkRunSetup benchmarkRunSetup = runSpecification.getBenchmarkRunSetup();
		Path logDir = benchmarkRunSetup.getLogDir().resolve("platform").resolve("runner.logs");
		Neo4jCollector.startPlatformLogging(logDir);
	}

	@Override
	public void run(RunSpecification runSpecification) throws PlatformExecutionException {
		BenchmarkRun benchmarkRun = runSpecification.getBenchmarkRun();
		BenchmarkRunSetup benchmarkRunSetup = runSpecification.getBenchmarkRunSetup();
		RuntimeSetup runtimeSetup = runSpecification.getRuntimeSetup();

		Algorithm algorithm = benchmarkRun.getAlgorithm();
		Neo4jConfiguration platformConfig = Neo4jConfiguration.parsePropertiesFile();
		String inputPath = runtimeSetup.getLoadedGraph().getLoadedPath();
		String outputPath = benchmarkRunSetup.getOutputDir().resolve(benchmarkRun.getName()).toAbsolutePath().toString();

		AbstractNeo4jJobFactory jobFactory;
		switch (platformConfig.getBenchmarkImplementation()) {
			case ALGOLIB:
				jobFactory = new AlgolibNeo4jJobFactory(
						runSpecification, platformConfig, inputPath, outputPath
				);
				break;
			case EMBEDDED:
				jobFactory = new EmbeddedNeo4jJobFactory(
						runSpecification, platformConfig, inputPath, outputPath
				);
				break;
			default:
				throw new PlatformExecutionException("Benchmark implementation is not defined");
		}

		Neo4jJob job;
		switch (algorithm) {
			case BFS:
				job = jobFactory.createBfsJob();
				break;
			case CDLP:
				job = jobFactory.createCdlpJob();
				break;
			case LCC:
				job = jobFactory.createLccJob();
				break;
			case PR:
				job = jobFactory.createPrJob();
				break;
			case WCC:
				job = jobFactory.createWccJob();
				break;
			case SSSP:
				job = jobFactory.createSsspJob();
				break;
			default:
				throw new PlatformExecutionException("Failed to load algorithm implementation.");
		}

		LOG.info("Executing benchmark with algorithm \"{}\" on graph \"{}\".",
				benchmarkRun.getAlgorithm().getName(),
				benchmarkRun.getFormattedGraph().getName());

		try {
			int exitCode = job.execute();
			if (exitCode != 0) {
				throw new PlatformExecutionException("Neo4j exited with an error code: " + exitCode);
			}
		} catch (Exception e) {
			throw new PlatformExecutionException("Failed to execute a Neo4j job.", e);
		}

		LOG.info("Executed benchmark with algorithm \"{}\" on graph \"{}\".",
				benchmarkRun.getAlgorithm().getName(),
				benchmarkRun.getFormattedGraph().getName());
	}

	@Override
	public BenchmarkMetrics finalize(RunSpecification runSpecification) throws Exception {
		Neo4jCollector.stopPlatformLogging();
		BenchmarkRunSetup benchmarkRunSetup = runSpecification.getBenchmarkRunSetup();
		Path logDir = benchmarkRunSetup.getLogDir().resolve("platform");

		BenchmarkMetrics metrics = new BenchmarkMetrics();
		metrics.setProcessingTime(Neo4jCollector.collectProcessingTime(logDir));
		return metrics;
	}

	@Override
	public void terminate(RunSpecification runSpecification) {
		BenchmarkRunner.terminatePlatform(runSpecification);
	}

	@Override
	public String getPlatformName() {
		return PLATFORM_NAME;
	}
}
