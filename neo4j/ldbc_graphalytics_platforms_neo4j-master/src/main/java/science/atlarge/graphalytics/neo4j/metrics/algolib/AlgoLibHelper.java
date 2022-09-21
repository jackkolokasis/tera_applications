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
package science.atlarge.graphalytics.neo4j.metrics.algolib;

import org.neo4j.graphdb.DependencyResolver;
import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.internal.kernel.api.exceptions.KernelException;
import org.neo4j.kernel.impl.proc.Procedures;
import org.neo4j.kernel.internal.GraphDatabaseAPI;

public class AlgoLibHelper {

    public static void registerProcedure(GraphDatabaseService db, Class<?>... procedures) throws KernelException {
        Procedures proceduresService = ((GraphDatabaseAPI) db)
                .getDependencyResolver()
                .resolveDependency(
                        Procedures.class,
                        DependencyResolver.SelectionStrategy.ONLY
                );

        for (Class<?> procedure : procedures) {
            proceduresService.registerProcedure(procedure);
            proceduresService.registerFunction(procedure);
        }
    }

}
