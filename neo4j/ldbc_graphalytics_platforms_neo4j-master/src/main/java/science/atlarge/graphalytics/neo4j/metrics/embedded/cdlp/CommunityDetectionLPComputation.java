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
package science.atlarge.graphalytics.neo4j.metrics.embedded.cdlp;

import it.unimi.dsi.fastutil.longs.Long2LongMap;
import it.unimi.dsi.fastutil.longs.Long2LongOpenHashMap;
import it.unimi.dsi.fastutil.objects.Object2LongMap;
import it.unimi.dsi.fastutil.objects.Object2LongOpenHashMap;
import org.neo4j.graphdb.Direction;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Node;
import org.neo4j.graphdb.Relationship;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.*;

/**
 * Implementation of the community detection algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class CommunityDetectionLPComputation {

	private final GraphDatabaseService graphDatabase;
	private final int maxIterations;
	private Object2LongMap<Node> labels;
	private Object2LongMap<Node> newLabels;
	private Long2LongMap labelCounts = new Long2LongOpenHashMap();

	/**
	 * @param graphDatabase graph database representing the input graph
	 * @param maxIterations maximum number of iterations of the label propagation to run
	 */
	public CommunityDetectionLPComputation(GraphDatabaseService graphDatabase, int maxIterations) {
		this.graphDatabase = graphDatabase;
		this.maxIterations = maxIterations;
	}

	/**
	 * Executes the community detection algorithm by setting the LABEL property of all nodes to the label of the
	 * community to which the node belongs.
	 */
	public void run() {
		try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
			// Initialize the label of each node to its own ID
			labels = initializeLabels();
			newLabels = new Object2LongOpenHashMap<>(labels.size());

			int iteration = 0;
			boolean converged = false;
			while (!converged && iteration < maxIterations) {
				converged = true;
				for (Node node : labels.keySet()) {
					long newLabel = computeNewLabel(node);
					newLabels.put(node, newLabel);

					if (labels.get(node) != newLabel) {
						converged = false;
					}
				}

				swapLabelMaps();

				iteration++;
			}

			writeLabels(transactionManager);
		}
	}

	private Object2LongMap<Node> initializeLabels() {
		Object2LongMap<Node> labels = new Object2LongOpenHashMap<>();
		for (Node node : graphDatabase.getAllNodes()) {
			labels.put(node, (long)node.getProperty(ID_PROPERTY));
		}
		return labels;
	}

	private long computeNewLabel(Node node) {
		// Count the frequency of labels at neighbours of the current node
		labelCounts.clear();
		labelCounts.defaultReturnValue(0L);
		for (Relationship relationship : node.getRelationships(EDGE, Direction.BOTH)) {
			long otherLabel = labels.get(relationship.getOtherNode(node));
			labelCounts.put(otherLabel, labelCounts.get(otherLabel) + 1);
		}

		// Find the most frequent label with the lowest id
		long bestLabel = labels.get(node);
		long bestFrequency = 0;
		for (Long2LongMap.Entry labelFrequencyPair : labelCounts.long2LongEntrySet()) {
			long nextLabel = labelFrequencyPair.getLongKey();
			long nextFrequency = labelFrequencyPair.getLongValue();
			if (nextFrequency > bestFrequency) {
				bestLabel = nextLabel;
				bestFrequency = nextFrequency;
			} else if (nextFrequency == bestFrequency && nextLabel < bestLabel) {
				bestLabel = nextLabel;
			}
		}
		return bestLabel;
	}

	private void swapLabelMaps() {
		Object2LongMap<Node> temp = labels;
		labels = newLabels;
		newLabels = temp;
	}

	private void writeLabels(Neo4jTransactionManager transactionManager) {
		for (Node node : labels.keySet()) {
			node.setProperty(LABEL, labels.get(node));
			transactionManager.incrementOperations();
		}
	}

}
