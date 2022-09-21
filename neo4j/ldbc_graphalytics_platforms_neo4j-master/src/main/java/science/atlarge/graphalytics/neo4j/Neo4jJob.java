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
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.domain.benchmark.BenchmarkRun;
import science.atlarge.graphalytics.domain.graph.Graph;
import science.atlarge.graphalytics.execution.BenchmarkRunSetup;
import science.atlarge.graphalytics.execution.RunSpecification;

import java.io.IOException;


/**
 * Base class for all jobs in the platform driver. Configures and executes a platform job using the parameters
 * and executable specified by the subclass for a specific algorithm.
 *
 * @author Gábor Szárnyas
 * @author Bálint Hegyi
 */
public abstract class Neo4jJob {
    // Path to the Neo4j configuration
    private static final String PROPERTIES_PATH = "/neo4j.properties";
    private static final Logger LOG = LogManager.getLogger();

    private final String jobId;
    private final String logPath;
    private final String inputPath;
    private final String outputPath;

    private final Graph graph;
    private final Neo4jDatabase database;

    /**
     * Initializes the platform job with its parameters.
     *
     * @param runSpecification the benchmark run specification.
     * @param platformConfig   the platform configuration.
     * @param inputPath        the file path of the input graph dataset.
     * @param outputPath       the file path of the output graph dataset.
     */
    public Neo4jJob(RunSpecification runSpecification,
                    Neo4jConfiguration platformConfig,
                    String inputPath,
                    String outputPath) {

        BenchmarkRun benchmarkRun = runSpecification.getBenchmarkRun();
        BenchmarkRunSetup benchmarkRunSetup = runSpecification.getBenchmarkRunSetup();

        this.jobId = benchmarkRun.getId();
        this.logPath = benchmarkRunSetup.getLogDir().resolve("platform").toString();

        this.inputPath = inputPath;
        this.outputPath = outputPath;

        this.graph = benchmarkRun.getGraph();

        LOG.info("Starting database from path: " + inputPath);
        LOG.info("Database properties path: " + Neo4jJob.class.getResource(PROPERTIES_PATH));
        this.database = new Neo4jDatabase(
                inputPath,
                Neo4jJob.class.getResource(PROPERTIES_PATH)
        );
    }

    /**
     * Executes the platform job with the pre-defined parameters.
     *
     * @return the exit code
     */
    public int execute() throws KernelException, IOException {
        compute(
                database.get(),
                graph
        );
        serialize(
                database.get(),
                outputPath
        );
        return 0;
    }

    protected abstract void compute(
            GraphDatabaseService graphDatabase,
            Graph graph
    ) throws KernelException, IOException;

    protected void serialize(
            GraphDatabaseService graphDatabase,
            String outputPath
    ) throws IOException { }

}
