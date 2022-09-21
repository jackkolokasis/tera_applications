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
package science.atlarge.graphalytics.neo4j.metrics.algolib.cdlp;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.neo4j.graphalgo.labelpropagation.LabelPropagationWriteProc;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgoLibHelper;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.LABEL;

/**
 * Implementation of the community detection algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class CommunityDetectionLPComputation {

    private static final Logger LOG = LogManager.getLogger();

    private final GraphDatabaseService graphDatabase;
    private final int maxIterations;
    private final boolean directed;

    /**
     * @param graphDatabase graph database representing the input graph
     * @param maxIterations maximum number of iterations of the label propagation to run
     */
    public CommunityDetectionLPComputation(
            GraphDatabaseService graphDatabase,
            int maxIterations,
            boolean directed
    ) throws KernelException {
        this.graphDatabase = graphDatabase;
        this.maxIterations = maxIterations;
        this.directed = directed;

        AlgoLibHelper.registerProcedure(graphDatabase, LabelPropagationWriteProc.class);
    }

    /**
     * Executes the community detection algorithm by setting the LABEL property of all nodes to the label of the
     * community to which the node belongs.
     */
    public void run() {
        LOG.debug("- Starting Community Detection Label Propagation algorithm");
        // the CDLP (label propagation) computation is defined in
        // https://github.com/neo4j/graph-data-science/blob/master/algo/src/main/java/org/neo4j/graphalgo/labelpropagation/ComputeStep.java
        try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
            final String command = String.format("" +
                            "CALL gds.labelPropagation.write({" +
                            "  nodeProjection: '*',\n" +
                            "  relationshipProjection: {\n" +
                            "    EDGE: {\n" +
                            "      orientation: '%s',\n" +
                            "      type: 'EDGE'\n" +
                            "    }\n" +
                            "  },\n" +
                            "  writeProperty: '%s'," +
                            "  maxIterations: %d " +
                            "})\n"+
                            "YIELD ranIterations, communityCount",
                    directed ? "NATURAL" : "UNDIRECTED",
                    LABEL,
                    maxIterations
            );
            graphDatabase.execute(command);
        }
        LOG.debug("- Completed Community Detection Label Propagation algorithm");
    }

}
