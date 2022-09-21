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

import org.apache.commons.configuration.Configuration;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import science.atlarge.graphalytics.configuration.ConfigurationUtil;
import science.atlarge.graphalytics.configuration.GraphalyticsExecutionException;

import java.nio.file.Paths;
import java.util.Objects;

/**
 * Collection of configurable platform options.
 *
 * @author Gábor Szárnyas
 * @author Bálint Hegyi
 */
public final class Neo4jConfiguration {

    protected static final Logger LOG = LogManager.getLogger();

    private static final String BENCHMARK_PROPERTIES_FILE = "benchmark.properties";
    private static final String HOME_PATH_KEY = "platform.neo4j.home";
    private static final String BENCHMARK_IMPL_KEY = "platform.impl";

    public enum BenchmarkImplementation {
        ALGOLIB,
        EMBEDDED
    }

    private String loaderPath;
    private String unloaderPath;
    private String executablePath;
    private String terminatorPath;
    private String homePath;
    private BenchmarkImplementation benchmarkImplementation;

    /**
     * Creates a new Neo4jConfiguration object to capture all platform parameters that are not specific to any algorithm.
     */
    public Neo4jConfiguration() {
    }

    public String getLoaderPath() {
        return loaderPath;
    }

    public void setLoaderPath(String loaderPath) {
        this.loaderPath = loaderPath;
    }

    public String getUnloaderPath() {
        return unloaderPath;
    }

    public void setUnloaderPath(String unloaderPath) {
        this.unloaderPath = unloaderPath;
    }

    /**
     * @param executablePath the directory containing executables
     */
    public void setExecutablePath(String executablePath) {
        this.executablePath = executablePath;
    }

    /**
     * @return the directory containing executables
     */
    public String getExecutablePath() {
        return executablePath;
    }

    public String getTerminatorPath() {
        return terminatorPath;
    }

    public void setTerminatorPath(String terminatorPath) {
        this.terminatorPath = terminatorPath;
    }

    /**
     * @return the home directory
     */
    public String getHomePath() {
        return homePath;
    }

    /**
     * @param homePath the home directory
     */
    public void setHomePath(String homePath) {
        this.homePath = homePath;
    }

    public BenchmarkImplementation getBenchmarkImplementation() {
        return benchmarkImplementation;
    }

    public void setBenchmarkImplementation(BenchmarkImplementation benchmarkImplementation) {
        this.benchmarkImplementation = benchmarkImplementation;
    }

    public static Neo4jConfiguration parsePropertiesFile() {

        Neo4jConfiguration platformConfig = new Neo4jConfiguration();

        Configuration configuration = null;
        try {
            configuration = ConfigurationUtil.loadConfiguration(BENCHMARK_PROPERTIES_FILE);
        } catch (Exception e) {
            LOG.warn(String.format("Failed to load configuration from %s", BENCHMARK_PROPERTIES_FILE));
            throw new GraphalyticsExecutionException("Failed to load configuration. Benchmark run aborted.", e);
        }

        String loaderPath = Paths.get("./bin/sh/load-graph.sh").toString();
        platformConfig.setLoaderPath(loaderPath);

        String unloaderPath = Paths.get("./bin/sh/unload-graph.sh").toString();
        platformConfig.setUnloaderPath(unloaderPath);

        String executablePath = Paths.get("./bin/sh/execute-job.sh").toString();
        platformConfig.setExecutablePath(executablePath);

        String terminatorPath = Paths.get("./bin/sh/terminate-job.sh").toString();
        platformConfig.setTerminatorPath(terminatorPath);

        String homePath = configuration.getString(HOME_PATH_KEY, null);
        if (homePath != null) {
            platformConfig.setHomePath(homePath);
        }

        String benchmarkImpl = configuration.getString(BENCHMARK_IMPL_KEY, null);
        Objects.requireNonNull(
                benchmarkImpl,
                String.format("The key %s is not defined", BENCHMARK_IMPL_KEY)
        );
        platformConfig.setBenchmarkImplementation(
                BenchmarkImplementation.valueOf(benchmarkImpl.toUpperCase())
        );

        return platformConfig;
    }

}
