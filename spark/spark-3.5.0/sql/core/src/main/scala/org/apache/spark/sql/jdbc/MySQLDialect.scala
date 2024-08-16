/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.sql.jdbc

import java.sql.{Connection, SQLException, Types}
import java.util
import java.util.Locale

import scala.collection.mutable.ArrayBuilder
import scala.util.control.NonFatal

import org.apache.spark.sql.AnalysisException
import org.apache.spark.sql.catalyst.SQLConfHelper
import org.apache.spark.sql.catalyst.analysis.{IndexAlreadyExistsException, NoSuchIndexException}
import org.apache.spark.sql.connector.catalog.Identifier
import org.apache.spark.sql.connector.catalog.index.TableIndex
import org.apache.spark.sql.connector.expressions.{Expression, FieldReference, NamedReference, NullOrdering, SortDirection}
import org.apache.spark.sql.errors.QueryExecutionErrors
import org.apache.spark.sql.execution.datasources.jdbc.{JDBCOptions, JdbcUtils}
import org.apache.spark.sql.types.{BooleanType, DataType, FloatType, LongType, MetadataBuilder, StringType}

private case object MySQLDialect extends JdbcDialect with SQLConfHelper {

  override def canHandle(url : String): Boolean =
    url.toLowerCase(Locale.ROOT).startsWith("jdbc:mysql")

  private val distinctUnsupportedAggregateFunctions =
    Set("VAR_POP", "VAR_SAMP", "STDDEV_POP", "STDDEV_SAMP")

  // See https://dev.mysql.com/doc/refman/8.0/en/aggregate-functions.html
  private val supportedAggregateFunctions =
    Set("MAX", "MIN", "SUM", "COUNT", "AVG") ++ distinctUnsupportedAggregateFunctions
  private val supportedFunctions = supportedAggregateFunctions

  override def isSupportedFunction(funcName: String): Boolean =
    supportedFunctions.contains(funcName)

  class MySQLSQLBuilder extends JDBCSQLBuilder {
    override def visitSortOrder(
        sortKey: String, sortDirection: SortDirection, nullOrdering: NullOrdering): String = {
      (sortDirection, nullOrdering) match {
        case (SortDirection.ASCENDING, NullOrdering.NULLS_FIRST) =>
          s"$sortKey $sortDirection"
        case (SortDirection.ASCENDING, NullOrdering.NULLS_LAST) =>
          s"CASE WHEN $sortKey IS NULL THEN 1 ELSE 0 END, $sortKey $sortDirection"
        case (SortDirection.DESCENDING, NullOrdering.NULLS_FIRST) =>
          s"CASE WHEN $sortKey IS NULL THEN 0 ELSE 1 END, $sortKey $sortDirection"
        case (SortDirection.DESCENDING, NullOrdering.NULLS_LAST) =>
          s"$sortKey $sortDirection"
      }
    }

    override def visitAggregateFunction(
        funcName: String, isDistinct: Boolean, inputs: Array[String]): String =
      if (isDistinct && distinctUnsupportedAggregateFunctions.contains(funcName)) {
        throw new UnsupportedOperationException(s"${this.getClass.getSimpleName} does not " +
          s"support aggregate function: $funcName with DISTINCT");
      } else {
        super.visitAggregateFunction(funcName, isDistinct, inputs)
      }
  }

  override def compileExpression(expr: Expression): Option[String] = {
    val mysqlSQLBuilder = new MySQLSQLBuilder()
    try {
      Some(mysqlSQLBuilder.build(expr))
    } catch {
      case NonFatal(e) =>
        logWarning("Error occurs while compiling V2 expression", e)
        None
    }
  }

  override def getCatalystType(
      sqlType: Int, typeName: String, size: Int, md: MetadataBuilder): Option[DataType] = {
    if (sqlType == Types.VARBINARY && typeName.equals("BIT") && size != 1) {
      // This could instead be a BinaryType if we'd rather return bit-vectors of up to 64 bits as
      // byte arrays instead of longs.
      md.putLong("binarylong", 1)
      Option(LongType)
    } else if (sqlType == Types.BIT && typeName.equals("TINYINT")) {
      Option(BooleanType)
    } else if ("TINYTEXT".equalsIgnoreCase(typeName)) {
      // TINYTEXT is Types.VARCHAR(63) from mysql jdbc, but keep it AS-IS for historical reason
      Some(StringType)
    } else if (sqlType == Types.VARCHAR && typeName.equals("JSON")) {
      // Some MySQL JDBC drivers converts JSON type into Types.VARCHAR with a precision of -1.
      // Explicitly converts it into StringType here.
      Some(StringType)
    } else None
  }

  override def quoteIdentifier(colName: String): String = {
    s"`$colName`"
  }

  override def schemasExists(conn: Connection, options: JDBCOptions, schema: String): Boolean = {
    listSchemas(conn, options).exists(_.head == schema)
  }

  override def listSchemas(conn: Connection, options: JDBCOptions): Array[Array[String]] = {
    val schemaBuilder = ArrayBuilder.make[Array[String]]
    try {
      JdbcUtils.executeQuery(conn, options, "SHOW SCHEMAS") { rs =>
        while (rs.next()) {
          schemaBuilder += Array(rs.getString("Database"))
        }
      }
    } catch {
      case _: Exception =>
        logWarning("Cannot show schemas.")
    }
    schemaBuilder.result
  }

  override def getTableExistsQuery(table: String): String = {
    s"SELECT 1 FROM $table LIMIT 1"
  }

  override def isCascadingTruncateTable(): Option[Boolean] = Some(false)

  // See https://dev.mysql.com/doc/refman/8.0/en/alter-table.html
  override def getUpdateColumnTypeQuery(
      tableName: String,
      columnName: String,
      newDataType: String): String = {
    s"ALTER TABLE $tableName MODIFY COLUMN ${quoteIdentifier(columnName)} $newDataType"
  }

  // See Old Syntax: https://dev.mysql.com/doc/refman/5.6/en/alter-table.html
  // According to https://dev.mysql.com/worklog/task/?id=10761 old syntax works for
  // both versions of MySQL i.e. 5.x and 8.0
  // The old syntax requires us to have type definition. Since we do not have type
  // information, we throw the exception for old version.
  override def getRenameColumnQuery(
      tableName: String,
      columnName: String,
      newName: String,
      dbMajorVersion: Int): String = {
    if (dbMajorVersion >= 8) {
      s"ALTER TABLE $tableName RENAME COLUMN ${quoteIdentifier(columnName)} TO" +
        s" ${quoteIdentifier(newName)}"
    } else {
      throw QueryExecutionErrors.renameColumnUnsupportedForOlderMySQLError()
    }
  }

  // See https://dev.mysql.com/doc/refman/8.0/en/alter-table.html
  // require to have column data type to change the column nullability
  // ALTER TABLE tbl_name MODIFY [COLUMN] col_name column_definition
  // column_definition:
  //    data_type [NOT NULL | NULL]
  // e.g. ALTER TABLE t1 MODIFY b INT NOT NULL;
  // We don't have column data type here, so throw Exception for now
  override def getUpdateColumnNullabilityQuery(
      tableName: String,
      columnName: String,
      isNullable: Boolean): String = {
    throw QueryExecutionErrors.unsupportedUpdateColumnNullabilityError()
  }

  // See https://dev.mysql.com/doc/refman/8.0/en/alter-table.html
  override def getTableCommentQuery(table: String, comment: String): String = {
    s"ALTER TABLE $table COMMENT = '$comment'"
  }

  override def getJDBCType(dt: DataType): Option[JdbcType] = dt match {
    // See SPARK-35446: MySQL treats REAL as a synonym to DOUBLE by default
    // We override getJDBCType so that FloatType is mapped to FLOAT instead
    case FloatType => Option(JdbcType("FLOAT", java.sql.Types.FLOAT))
    case StringType => Option(JdbcType("LONGTEXT", java.sql.Types.LONGVARCHAR))
    case _ => JdbcUtils.getCommonJDBCType(dt)
  }

  override def getSchemaCommentQuery(schema: String, comment: String): String = {
    throw QueryExecutionErrors.unsupportedCommentNamespaceError(schema)
  }

  override def removeSchemaCommentQuery(schema: String): String = {
    throw QueryExecutionErrors.unsupportedRemoveNamespaceCommentError(schema)
  }

  // CREATE INDEX syntax
  // https://dev.mysql.com/doc/refman/8.0/en/create-index.html
  override def createIndex(
      indexName: String,
      tableIdent: Identifier,
      columns: Array[NamedReference],
      columnsProperties: util.Map[NamedReference, util.Map[String, String]],
      properties: util.Map[String, String]): String = {
    val columnList = columns.map(col => quoteIdentifier(col.fieldNames.head))
    val (indexType, indexPropertyList) = JdbcUtils.processIndexProperties(properties, "mysql")

    // columnsProperties doesn't apply to MySQL so it is ignored
    s"CREATE INDEX ${quoteIdentifier(indexName)} $indexType ON" +
      s" ${quoteIdentifier(tableIdent.name())} (${columnList.mkString(", ")})" +
      s" ${indexPropertyList.mkString(" ")}"
  }

  // SHOW INDEX syntax
  // https://dev.mysql.com/doc/refman/8.0/en/show-index.html
  override def indexExists(
      conn: Connection,
      indexName: String,
      tableIdent: Identifier,
      options: JDBCOptions): Boolean = {
    val sql = s"SHOW INDEXES FROM ${quoteIdentifier(tableIdent.name())} " +
      s"WHERE key_name = '$indexName'"
    JdbcUtils.checkIfIndexExists(conn, sql, options)
  }

  override def dropIndex(indexName: String, tableIdent: Identifier): String = {
    s"DROP INDEX ${quoteIdentifier(indexName)} ON ${tableIdent.name()}"
  }

  // SHOW INDEX syntax
  // https://dev.mysql.com/doc/refman/8.0/en/show-index.html
  override def listIndexes(
      conn: Connection,
      tableIdent: Identifier,
      options: JDBCOptions): Array[TableIndex] = {
    val sql = s"SHOW INDEXES FROM ${tableIdent.name()}"
    var indexMap: Map[String, TableIndex] = Map()
    try {
      JdbcUtils.executeQuery(conn, options, sql) { rs =>
        while (rs.next()) {
          val indexName = rs.getString("key_name")
          val colName = rs.getString("column_name")
          val indexType = rs.getString("index_type")
          val indexComment = rs.getString("index_comment")
          if (indexMap.contains(indexName)) {
            val index = indexMap.get(indexName).get
            val newIndex = new TableIndex(indexName, indexType,
              index.columns() :+ FieldReference(colName),
              index.columnProperties, index.properties)
            indexMap += (indexName -> newIndex)
          } else {
            // The only property we are building here is `COMMENT` because it's the only one
            // we can get from `SHOW INDEXES`.
            val properties = new util.Properties();
            if (indexComment.nonEmpty) properties.put("COMMENT", indexComment)
            val index = new TableIndex(indexName, indexType, Array(FieldReference(colName)),
              new util.HashMap[NamedReference, util.Properties](), properties)
            indexMap += (indexName -> index)
          }
        }
      }
    } catch {
      case _: Exception =>
        logWarning("Cannot retrieved index info.")
    }
    indexMap.values.toArray
  }

  override def classifyException(message: String, e: Throwable): AnalysisException = {
    e match {
      case sqlException: SQLException =>
        sqlException.getErrorCode match {
          // ER_DUP_KEYNAME
          case 1061 =>
            // The message is: Failed to create index indexName in tableName
            val regex = "(?s)Failed to create index (.*) in (.*)".r
            val indexName = regex.findFirstMatchIn(message).get.group(1)
            val tableName = regex.findFirstMatchIn(message).get.group(2)
            throw new IndexAlreadyExistsException(
              indexName = indexName, tableName = tableName, cause = Some(e))
          case 1091 =>
            // The message is: Failed to drop index indexName in tableName
            val regex = "(?s)Failed to drop index (.*) in (.*)".r
            val indexName = regex.findFirstMatchIn(message).get.group(1)
            val tableName = regex.findFirstMatchIn(message).get.group(2)
            throw new NoSuchIndexException(indexName, tableName, cause = Some(e))
          case _ => super.classifyException(message, e)
        }
      case unsupported: UnsupportedOperationException => throw unsupported
      case _ => super.classifyException(message, e)
    }
  }

  override def dropSchema(schema: String, cascade: Boolean): String = {
    if (cascade) {
      s"DROP SCHEMA ${quoteIdentifier(schema)}"
    } else {
      throw QueryExecutionErrors.unsupportedDropNamespaceError(schema)
    }
  }

  class MySQLSQLQueryBuilder(dialect: JdbcDialect, options: JDBCOptions)
    extends JdbcSQLQueryBuilder(dialect, options) {

    override def build(): String = {
      val limitOrOffsetStmt = if (limit > 0) {
        if (offset > 0) {
          s"LIMIT $offset, $limit"
        } else {
          dialect.getLimitClause(limit)
        }
      } else if (offset > 0) {
        // MySQL doesn't support OFFSET without LIMIT. According to the suggestion of MySQL
        // official website, in order to retrieve all rows from a certain offset up to the end of
        // the result set, you can use some large number for the second parameter. Please refer:
        // https://dev.mysql.com/doc/refman/8.0/en/select.html
        s"LIMIT $offset, 18446744073709551615"
      } else {
        ""
      }

      options.prepareQuery +
        s"SELECT $columnList FROM ${options.tableOrQuery} $tableSampleClause" +
        s" $whereClause $groupByClause $orderByClause $limitOrOffsetStmt"
    }
  }

  override def getJdbcSQLQueryBuilder(options: JDBCOptions): JdbcSQLQueryBuilder =
    new MySQLSQLQueryBuilder(this, options)

  override def supportsLimit: Boolean = true

  override def supportsOffset: Boolean = true
}
