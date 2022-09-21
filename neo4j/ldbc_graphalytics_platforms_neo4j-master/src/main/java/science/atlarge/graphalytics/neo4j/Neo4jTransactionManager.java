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

import org.neo4j.graphdb.GraphDatabaseService;
import org.neo4j.graphdb.Transaction;

/**
 * Utility class for managing transactions in Neo4j. Tracks the number of operations in a transaction to commit
 * whenever a threshold is reached.
 *
 * @author Tim Hegeman
 */
public class Neo4jTransactionManager implements AutoCloseable {

	public static final long DEFAULT_MAXIMUM_OPERATIONS_PER_TRANSACTION = 4095;

	private final GraphDatabaseService db;
	private final long maximumOperationsPerTransaction;
	private Transaction transaction;
	private long operationsInTransaction;

	public Neo4jTransactionManager(GraphDatabaseService db) {
		this(db, DEFAULT_MAXIMUM_OPERATIONS_PER_TRANSACTION);
	}

	public Neo4jTransactionManager(GraphDatabaseService db, long maximumOperationsPerTransaction) {
		this.db = db;
		this.maximumOperationsPerTransaction = maximumOperationsPerTransaction;
		this.transaction = db.beginTx();
		this.operationsInTransaction = 0;
	}

	public void incrementOperations() {
		operationsInTransaction++;
		if (operationsInTransaction == maximumOperationsPerTransaction) {
			transaction.success();
			transaction.close();
			transaction = db.beginTx();
			operationsInTransaction = 0;
		}
	}

	public void forceCommit() {
		transaction.success();
		transaction.close();
		transaction = db.beginTx();
		operationsInTransaction = 0;
	}

	@Override
	public void close() {
		transaction.success();
		transaction.close();
	}
}
