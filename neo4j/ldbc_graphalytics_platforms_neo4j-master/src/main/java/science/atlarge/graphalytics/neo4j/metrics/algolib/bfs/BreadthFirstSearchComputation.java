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
package science.atlarge.graphalytics.neo4j.metrics.algolib.bfs;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
//import org.neo4j.graphalgo.ShortestPathProc;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.neo4j.Neo4jConstants;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgoLibHelper;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.DISTANCE;

/**
 * Implementation of the breadth-first search algorithm in Neo4j. This class is responsible for the computation of the
 * distance to each node from the start node, given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class BreadthFirstSearchComputation {

    private static final Logger LOG = LogManager.getLogger();

    private final GraphDatabaseService graphDatabase;
    private final long startVertexId;
    private final boolean directed;

    /**
     * @param graphDatabase graph database representing the input graph
     * @param startVertexId source vertex for the breadth-first search
     */
    public BreadthFirstSearchComputation(
            GraphDatabaseService graphDatabase,
            long startVertexId,
            boolean directed
    ) throws KernelException {
        this.graphDatabase = graphDatabase;
        this.startVertexId = startVertexId;
        this.directed = directed;

        //AlgoLibHelper.registerProcedure(graphDatabase, ShortestPathProc.class);
    }

    /**
     * Executes the breadth-first search algorithm by setting the DISTANCE property of all nodes reachable from the
     * start vertex.
     */
    public void run() {
        LOG.debug("- Starting BFS algorithm");
        try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
            final String command = String.format("" +
                            "MATCH (startNode {%s: %d}), (endNode)\n" +
                            "CALL gds.alpha.shortestPath.write(startNode, endNode, null,\n" +
                            "  {write: true, writeProperty: '%s', direction: '%s'}\n" +
                            ")\n" +
                            "YIELD nodeCount, totalCost, loadMillis, evalMillis, writeMillis\n" +
                            "RETURN count(*)",
                    Neo4jConstants.ID_PROPERTY,
                    startVertexId,
                    DISTANCE,
                    directed ? "OUTGOING" : "BOTH"
            );
            graphDatabase.execute(command);
        }
        LOG.debug("- Completed BFS algorithm");
    }

}
