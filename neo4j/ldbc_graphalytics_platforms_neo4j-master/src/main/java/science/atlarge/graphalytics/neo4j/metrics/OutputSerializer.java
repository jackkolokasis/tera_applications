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
package science.atlarge.graphalytics.neo4j.metrics;

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Node;
import org.neo4j.graphdb.Transaction;

import java.io.FileWriter;
import java.io.IOException;

import static science.atlarge.graphalytics.neo4j.Neo4jConstants.ID_PROPERTY;

/**
 * Generic class for serializing the output of a metric.
 * <p>
 * This class assumes that:
 * <ul>
 *     <li>the results are stored as properties</li>
 *     <li>the results are descendant of the {@link Number} class</li>
 * </ul>
 *
 * @param <N> is the type of variable
 *
 * @author Bálint Hegyi
 */
public class OutputSerializer<N extends Number> {

    private final String property;
    private final N defaultValue;

    /**
     * Instantiates a new {@link OutputSerializer}
     * @param property the name of the property storing the result
     * @param defaultValue a value which should be used if the property is not
     *                     set on a node
     */
    public OutputSerializer(String property, N defaultValue) {
        this.property = property;
        this.defaultValue = defaultValue;
    }

    /**
     * Serializes the {@code graphDatabase} parameter into the file {@code outputPath}
     * <p>
     * The serialization will decide what format it should write out the results:
     * <ul>
     *     <li>{@link Double} or {@link Float}: in scientific notation</li>
     *     <li>Else: decimal number notation</li>
     * </ul>
     *
     * @param graphDatabase the database serialized
     * @param outputPath the path where the output file should be written
     * @throws IOException when the file cannot be opened
     */
    public void serialize(
            GraphDatabaseService graphDatabase,
            String outputPath) throws IOException {
        try (FileWriter writer = new FileWriter(outputPath)) {
            try (Transaction ignored = graphDatabase.beginTx()) {
                for (Node node : graphDatabase.getAllNodes()) {
                    writer.write(serializeValue(node, this.property) + "\n");
                }
            }
        }
    }

    private String serializeValue(Node node, String property) {
        long id = ((Number) node.getProperty(ID_PROPERTY)).longValue();
        N value = (N) node.getProperty(property, this.defaultValue);

        if (value instanceof Double || value instanceof Float) {
            return String.format("%d %e", id, value.doubleValue());
        } else {
            return String.format("%d %d", id, value.longValue());
        }

    }
}
