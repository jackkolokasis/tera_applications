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
package science.atlarge.graphalytics.neo4j.metrics.algolib.lcc;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
//import org.neo4j.graphalgo.TriangleProc;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgoLibHelper;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.LCC;

/**
 * Implementation of the local clustering coefficient algorithm in Neo4j. This class is responsible for the computation,
 * given a functional Neo4j database instance.
 *
 * @author Tim Hegeman
 */
public class LocalClusteringCoefficientComputation {

	private static final Logger LOG = LogManager.getLogger();

	private final GraphDatabaseService graphDatabase;
	private final boolean directed;

	/**
	 * @param graphDatabase graph database representing the input graph
	 */
	public LocalClusteringCoefficientComputation(
			GraphDatabaseService graphDatabase,
			boolean directed
	) throws KernelException {
		this.graphDatabase = graphDatabase;
		this.directed = directed;

	//	AlgoLibHelper.registerProcedure(graphDatabase, TriangleProc.class);
	}

	/**
	 * Executes the local clustering coefficient algorithm by setting the LCC property on all nodes.
	 */
	public void run() {
		LOG.debug("- Starting Local Clustering Coefficient computation algorithm");

		if (directed) {
			throw new UnsupportedOperationException("Directed LCC algorithm not yet supported");
		}
		try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
			final String command = String.format("" +
					"CALL alpha.triangle.triangleCount(null, null, {write: true, clusteringCoefficientProperty: '%s'})\n" +
					"YIELD loadMillis, computeMillis, writeMillis, nodeCount, triangleCount, averageClusteringCoefficient",
					LCC
			);
			graphDatabase.execute(command);
		}
		LOG.debug("- Completed Local Clustering Coefficient computation algorithm");
	}


}
