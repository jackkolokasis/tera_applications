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
package science.atlarge.graphalytics.neo4j.metrics.embedded.bfs;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.neo4j.graphdb.Direction;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Node;
import org.neo4j.graphdb.Relationship;
import science.atlarge.graphalytics.neo4j.Neo4jConstants;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;

import java.util.HashSet;
import java.util.Set;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.DISTANCE;
import static science.atlarge.graphalytics.neo4j.Neo4jConstants.ID_PROPERTY;
import static science.atlarge.graphalytics.neo4j.Neo4jConstants.VertexLabelEnum.Vertex;

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
    private final boolean directedGraph;
    private Set<Node> currentFrontier;
    private Set<Node> nextFrontier;

    /**
     * @param graphDatabase graph database representing the input graph
     * @param startVertexId source vertex for the breadth-first search
     */
    BreadthFirstSearchComputation(GraphDatabaseService graphDatabase, long startVertexId, boolean directedGraph) {
        this.graphDatabase = graphDatabase;
        this.startVertexId = startVertexId;
        this.directedGraph = directedGraph;
    }

    /**
     * Executes the breadth-first search algorithm by setting the DISTANCE property of all nodes reachable from the
     * start vertex.
     */
    public void run() {
        long distance = 0;
        nextFrontier = new HashSet<>();

        LOG.debug("- Starting BFS algorithm");
        try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
            Node startNode = graphDatabase.findNode(Vertex, ID_PROPERTY, startVertexId);
            startNode.setProperty(DISTANCE, distance);
            nextFrontier.add(startNode);

            LOG.debug("- Starting BFS at node \"{}\"", startNode.getId());

            Direction traversalDirection = directedGraph ? Direction.OUTGOING : Direction.BOTH;

            while (!nextFrontier.isEmpty()) {
                switchFrontiers();
                distance++;
                for (Node currentFrontierNode : currentFrontier) {
                    for (Relationship relationship : currentFrontierNode.getRelationships(Neo4jConstants.EDGE, traversalDirection)) {
                        Node nextFrontierNode = relationship.getEndNode();
                        if (!currentFrontier.contains(nextFrontierNode) && !nextFrontierNode.hasProperty(DISTANCE)) {
                            nextFrontierNode.setProperty(DISTANCE, distance);
                            nextFrontier.add(nextFrontierNode);
                            transactionManager.incrementOperations();
                        }
                    }
                }

                LOG.debug("- Finished iteration {} of BFS", distance);
            }
        }
        LOG.debug("- Completed BFS algorithm");
    }

    private void switchFrontiers() {
        currentFrontier = nextFrontier;
        nextFrontier = new HashSet<>();
    }
}
