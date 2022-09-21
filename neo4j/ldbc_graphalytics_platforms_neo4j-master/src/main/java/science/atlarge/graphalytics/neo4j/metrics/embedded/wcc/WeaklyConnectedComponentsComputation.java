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
package science.atlarge.graphalytics.neo4j.metrics.embedded.wcc;

import it.unimi.dsi.fastutil.objects.ObjectArrayFIFOQueue;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.neo4j.graphdb.*;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.*;
import static science.atlarge.graphalytics.neo4j.Neo4jConstants.VertexLabelEnum.Vertex;

/**
 * Implementation of the connected components algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class WeaklyConnectedComponentsComputation {

	private static final Logger LOG = LogManager.getLogger();


	private final GraphDatabaseService graphDatabase;

	/**
	 * @param graphDatabase graph database representing the input graph
	 */
	public WeaklyConnectedComponentsComputation(GraphDatabaseService graphDatabase) {
		this.graphDatabase = graphDatabase;
	}

	/**
	 * Executes the connected components algorithm by setting the COMPONENT property of all nodes to the smallest node
	 * ID in each component.
	 */
	public void run() {
		LOG.debug("- Starting Weakly Connected Components algorithm");
		ObjectArrayFIFOQueue<Node> nodesToVisit = new ObjectArrayFIFOQueue<>();
		try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
			for (Node node : graphDatabase.getAllNodes()) {
				if (!node.hasProperty(COMPONENT)) {
					Object nodeId = node.getProperty(ID_PROPERTY);
					nodesToVisit.clear();
					nodesToVisit.enqueue(node);
					node.setProperty(COMPONENT, nodeId);

					LOG.trace("  - Exploring new component from vertex {}", nodeId);
					exploreComponent(nodeId, nodesToVisit, transactionManager);
					if (LOG.isTraceEnabled()) {
						ResourceIterator<Node> componentNodes = graphDatabase.findNodes(Vertex, COMPONENT, nodeId);
						long componentSize = 0;
						while (componentNodes.hasNext()) {
							componentNodes.next();
							componentSize++;
						}
						LOG.trace("  - Find component of size {} containing vertex {}", componentSize, nodeId);
					}
				}
			}
		}
		LOG.debug("- Completed Weakly Connected Components algorithm");
	}

	private void exploreComponent(Object componentId, ObjectArrayFIFOQueue<Node> nodesToVisit,
			Neo4jTransactionManager transactionManager) {
		while (!nodesToVisit.isEmpty()) {
			Node currentNode = nodesToVisit.dequeue();
			for (Relationship relationship : currentNode.getRelationships(EDGE, Direction.BOTH)) {
				Node otherNode = relationship.getOtherNode(currentNode);
				if (!otherNode.hasProperty(COMPONENT)) {
					otherNode.setProperty(COMPONENT, componentId);
					nodesToVisit.enqueue(otherNode);
					transactionManager.incrementOperations();
				}
			}
		}
	}

}
