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
package science.atlarge.graphalytics.neo4j.metrics.algolib.sssp;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.neo4j.graphalgo.shortestpath.ShortestPathDeltaSteppingProc;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Result;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.neo4j.Neo4jConstants;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgoLibHelper;

import java.util.HashMap;
import java.util.Map;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.SSSP;

/**
 * Implementation of the connected components algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class SingleSourceShortestPathsComputation {

    private static final Logger LOG = LogManager.getLogger();

    private final GraphDatabaseService graphDatabase;
    private final long startVertexId;
    private final boolean directed;

    /**
     * @param graphDatabase graph database representing the input graph
     */
    public SingleSourceShortestPathsComputation(
            GraphDatabaseService graphDatabase,
            long startVertexId,
            boolean directed
    ) throws KernelException {
        this.graphDatabase = graphDatabase;
        this.startVertexId = startVertexId;
        this.directed = directed;

        AlgoLibHelper.registerProcedure(graphDatabase, ShortestPathDeltaSteppingProc.class);
    }

    /**
     * Executes the connected components algorithm by setting the SSSP property of all nodes to the smallest node
     * ID in each component.
     */
    public Map<Long, Double> run() {
        LOG.debug("- Starting Single Source Shortest Paths algorithm");
        Map<Long, Double> costs = new HashMap<>();
        try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
            final String command = String.format("" +
                            "MATCH (startNode {%s: %d})\n" +
                            "CALL gds.alpha.shortestPath.deltaStepping.write({\n" +
                            "  nodeProjection: '*',\n" +
                            "  relationshipProjection: {\n" +
                            "    EDGE: {\n" +
                            "      orientation: '%s',\n" +
                            "      type: 'EDGE',\n" +
                            "      properties: '%s'\n" +
                            "    }\n" +
                            "  },\n" +
                            "  startNode: startNode,\n" +
                            "  relationshipWeightProperty: '%s' \n,"+
                            "  delta: 3.0,\n" +
                            "  writeProperty: '%s'\n" +
                            "})\n" +
                            "YIELD nodeCount, loadDuration, evalDuration, writeDuration\n" +
                            "RETURN nodeCount, loadDuration, evalDuration, writeDuration",
                    Neo4jConstants.ID_PROPERTY,
                    startVertexId,
                    directed ? "NATURAL" : "UNDIRECTED",
                    Neo4jConstants.WEIGHT_PROPERTY,
                    Neo4jConstants.WEIGHT_PROPERTY,
                    SSSP
            );
            final Result result = graphDatabase.execute(command);
        }
        LOG.debug("- Completed Single Source Shortest Paths algorithm");
        return costs;
    }

}
