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
package science.atlarge.graphalytics.neo4j.metrics.algolib.wcc;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.neo4j.graphalgo.wcc.WccWriteProc;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import science.atlarge.graphalytics.neo4j.Neo4jTransactionManager;
import science.atlarge.graphalytics.neo4j.metrics.algolib.AlgoLibHelper;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.COMPONENT;


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
    public WeaklyConnectedComponentsComputation(GraphDatabaseService graphDatabase) throws KernelException {
        this.graphDatabase = graphDatabase;

        AlgoLibHelper.registerProcedure(graphDatabase, WccWriteProc.class);
    }

    /**
     * Executes the connected components algorithm by setting the COMPONENT property of all nodes to the smallest node
     * ID in each component.
     */
    public void run() {
        LOG.debug("- Starting Weakly Connected Components algorithm");
        try (Neo4jTransactionManager transactionManager = new Neo4jTransactionManager(graphDatabase)) {
            final String command = String.format("" +
                            "CALL gds.wcc.write({nodeProjection: '*',relationshipProjection: '*', writeProperty: '%s' })\n" +
                            "YIELD nodePropertiesWritten, componentCount;",
                    COMPONENT
            );
            graphDatabase.execute(command);
        }
        LOG.debug("- Completed Weakly Connected Components algorithm");
    }

}
