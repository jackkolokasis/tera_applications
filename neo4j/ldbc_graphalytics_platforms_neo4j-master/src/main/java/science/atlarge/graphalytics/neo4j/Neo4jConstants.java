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
package science.atlarge.graphalytics.neo4j;

import org.neo4j.graphdb.Label;
import org.neo4j.graphdb.RelationshipType;

/**
 * Class containing variables used to identify nodes, edges, and labels.
 *
 * @author Bálint Hegyi
 */
public final class Neo4jConstants {

    //
    // General graph constants
    //

    public static final RelationshipType EDGE = RelationshipType.withName("EDGE");
    public static final String ID_PROPERTY = "VID";
    public static final String WEIGHT_PROPERTY = "WEIGHT";

    //
    // Metric properties
    //

    /**
     * BFS result property
     */
    public static final String DISTANCE = "DISTANCE";
    /**
     * LCC result property
     */
    public static final String LCC = "LCC";
    /**
     * PageRank result property
     */
    public static final String PAGERANK = "PAGERANK";
    /**
     * WCC result property
     */
    public static final String COMPONENT = "COMPONENT";
    /**
     * SSSP result property
     */
    public static final String SSSP = "SSSP";
    /**
     * CDLP result property
     */
    public static final String LABEL = "LABEL";

    public enum VertexLabelEnum implements Label {
        Vertex
    }
}
