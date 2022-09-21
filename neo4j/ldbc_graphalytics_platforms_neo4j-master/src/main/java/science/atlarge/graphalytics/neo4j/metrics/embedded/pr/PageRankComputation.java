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
package science.atlarge.graphalytics.neo4j.metrics.embedded.pr;

import it.unimi.dsi.fastutil.objects.Object2DoubleMap;
import it.unimi.dsi.fastutil.objects.Object2DoubleOpenHashMap;
import org.neo4j.graphdb.Direction;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Node;
import org.neo4j.graphdb.Relationship;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.EDGE;
import static science.atlarge.graphalytics.neo4j.Neo4jConstants.PAGERANK;

/**
 * Implementation of the PageRank algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class PageRankComputation {

	private final GraphDatabaseService graphDatabase;
	private final int maxIterations;
	private final float dampingFactor;
	private final int numberOfVertices;

	private Object2DoubleMap<Node> prValues;
	private Object2DoubleMap<Node> newPrValues;
	private double danglingSum;
	private double newDanglingSum;

	/**
	 * @param graphDatabase    graph database representing the input graph
	 * @param maxIterations    maximum number of iterations of the PageRank algorithm to run
	 * @param dampingFactor    the damping factor parameter for the PageRank algorithm
	 * @param numberOfVertices the number of vertices in the graph
	 */
	public PageRankComputation(GraphDatabaseService graphDatabase, int maxIterations, float dampingFactor,
                               int numberOfVertices) {
		this.graphDatabase = graphDatabase;
		this.maxIterations = maxIterations;
		this.dampingFactor = dampingFactor;
		this.numberOfVertices = numberOfVertices;
	}

	/**
	 * Executes the PageRank algorithm by setting the PAGERANK property on all nodes.
	 */
	public void run() {
		try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
			// Initialize the PageRank value of each node to 1/numberOfVertices
			initializeValues();
			newPrValues = new Object2DoubleOpenHashMap<>(prValues.size());

			for (int iteration = 0; iteration < maxIterations; iteration++) {
				newDanglingSum = 0.0;

				for (Node node : prValues.keySet()) {
					computeNewValue(node);
				}

				swapAfterIteration();
			}

			writeValues(transactionManager);
		}
	}

	private void initializeValues() {
		int danglingNodeCount = 0;
		prValues = new Object2DoubleOpenHashMap<>(numberOfVertices);

		for (Node node : graphDatabase.getAllNodes()) {
			prValues.put(node, 1.0 / numberOfVertices);
			if (!node.hasRelationship(EDGE, Direction.OUTGOING)) {
				danglingNodeCount++;
			}
		}

		danglingSum = (double)danglingNodeCount / numberOfVertices;
	}

	private void computeNewValue(Node node) {
		double valueSum = danglingSum / numberOfVertices;
		for (Relationship relationship : node.getRelationships(EDGE, Direction.INCOMING)) {
			valueSum += prValues.get(relationship.getOtherNode(node)) /
					relationship.getOtherNode(node).getDegree(Direction.OUTGOING);
		}
		double newValue = (1.0 - dampingFactor) / numberOfVertices + dampingFactor * valueSum;

		newPrValues.put(node, newValue);
		if (!node.hasRelationship(EDGE, Direction.OUTGOING)) {
			newDanglingSum += newValue;
		}
	}

	private void swapAfterIteration() {
		Object2DoubleMap<Node> tempValues = prValues;
		prValues = newPrValues;
		newPrValues = tempValues;

		double tempDanglingSum = danglingSum;
		danglingSum = newDanglingSum;
		newDanglingSum = tempDanglingSum;
	}

	private void writeValues(Neo4jTransactionManager transactionManager) {
		for (Node node : prValues.keySet()) {
			node.setProperty(PAGERANK, prValues.get(node));
			transactionManager.incrementOperations();
		}
	}

}
