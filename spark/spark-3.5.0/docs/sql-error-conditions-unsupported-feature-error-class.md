---
layout: global
title: UNSUPPORTED_FEATURE error class
displayTitle: UNSUPPORTED_FEATURE error class
license: |
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
---

[SQLSTATE: 0A000](sql-error-conditions-sqlstates.html#class-0A-feature-not-supported)

The feature is not supported:

This error class has the following derived error classes:

## AES_MODE

AES-`<mode>` with the padding `<padding>` by the `<functionName>` function.

## AES_MODE_AAD

`<functionName>` with AES-`<mode>` does not support additional authenticate data (AAD).

## AES_MODE_IV

`<functionName>` with AES-`<mode>` does not support initialization vectors (IVs).

## ANALYZE_UNCACHED_TEMP_VIEW

The ANALYZE TABLE FOR COLUMNS command can operate on temporary views that have been cached already. Consider to cache the view `<viewName>`.

## ANALYZE_UNSUPPORTED_COLUMN_TYPE

The ANALYZE TABLE FOR COLUMNS command does not support the type `<columnType>` of the column `<columnName>` in the table `<tableName>`.

## ANALYZE_VIEW

The ANALYZE TABLE command does not support views.

## CATALOG_OPERATION

Catalog `<catalogName>` does not support `<operation>`.

## COMBINATION_QUERY_RESULT_CLAUSES

Combination of ORDER BY/SORT BY/DISTRIBUTE BY/CLUSTER BY.

## COMMENT_NAMESPACE

Attach a comment to the namespace `<namespace>`.

## DESC_TABLE_COLUMN_PARTITION

DESC TABLE COLUMN for a specific partition.

## DROP_DATABASE

Drop the default database `<database>`.

## DROP_NAMESPACE

Drop the namespace `<namespace>`.

## HIVE_TABLE_TYPE

The `<tableName>` is hive `<tableType>`.

## HIVE_WITH_ANSI_INTERVALS

Hive table `<tableName>` with ANSI intervals.

## INSERT_PARTITION_SPEC_IF_NOT_EXISTS

INSERT INTO `<tableName>` with IF NOT EXISTS in the PARTITION spec.

## LATERAL_COLUMN_ALIAS_IN_AGGREGATE_FUNC

Referencing a lateral column alias `<lca>` in the aggregate function `<aggFunc>`.

## LATERAL_COLUMN_ALIAS_IN_AGGREGATE_WITH_WINDOW_AND_HAVING

Referencing lateral column alias `<lca>` in the aggregate query both with window expressions and with having clause. Please rewrite the aggregate query by removing the having clause or removing lateral alias reference in the SELECT list.

## LATERAL_COLUMN_ALIAS_IN_GROUP_BY

Referencing a lateral column alias via GROUP BY alias/ALL is not supported yet.

## LATERAL_COLUMN_ALIAS_IN_WINDOW

Referencing a lateral column alias `<lca>` in window expression `<windowExpr>`.

## LATERAL_JOIN_USING

JOIN USING with LATERAL correlation.

## LITERAL_TYPE

Literal for '`<value>`' of `<type>`.

## MULTIPLE_BUCKET_TRANSFORMS

Multiple bucket TRANSFORMs.

## MULTI_ACTION_ALTER

The target JDBC server hosting table `<tableName>` does not support ALTER TABLE with multiple actions. Split the ALTER TABLE up into individual actions to avoid this error.

## ORC_TYPE_CAST

Unable to convert `<orcType>` of Orc to data type `<toType>`.

## PANDAS_UDAF_IN_PIVOT

Pandas user defined aggregate function in the PIVOT clause.

## PARAMETER_MARKER_IN_UNEXPECTED_STATEMENT

Parameter markers are not allowed in `<statement>`.

## PARTITION_WITH_NESTED_COLUMN_IS_UNSUPPORTED

Invalid partitioning: `<cols>` is missing or is in a map or array.

## PIVOT_AFTER_GROUP_BY

PIVOT clause following a GROUP BY clause. Consider pushing the GROUP BY into a subquery.

## PIVOT_TYPE

Pivoting by the value '`<value>`' of the column data type `<type>`.

## PURGE_PARTITION

Partition purge.

## PURGE_TABLE

Purge table.

## PYTHON_UDF_IN_ON_CLAUSE

Python UDF in the ON clause of a `<joinType>` JOIN. In case of an INNNER JOIN consider rewriting to a CROSS JOIN with a WHERE clause.

## REMOVE_NAMESPACE_COMMENT

Remove a comment from the namespace `<namespace>`.

## REPLACE_NESTED_COLUMN

The replace function does not support nested column `<colName>`.

## SET_NAMESPACE_PROPERTY

`<property>` is a reserved namespace property, `<msg>`.

## SET_OPERATION_ON_MAP_TYPE

Cannot have MAP type columns in DataFrame which calls set operations (INTERSECT, EXCEPT, etc.), but the type of column `<colName>` is `<dataType>`.

## SET_PROPERTIES_AND_DBPROPERTIES

set PROPERTIES and DBPROPERTIES at the same time.

## SET_TABLE_PROPERTY

`<property>` is a reserved table property, `<msg>`.

## TABLE_OPERATION

Table `<tableName>` does not support `<operation>`. Please check the current catalog and namespace to make sure the qualified table name is expected, and also check the catalog implementation which is configured by "spark.sql.catalog".

## TIME_TRAVEL

Time travel on the relation: `<relationId>`.

## TOO_MANY_TYPE_ARGUMENTS_FOR_UDF_CLASS

UDF class with `<num>` type arguments.

## TRANSFORM_DISTINCT_ALL

TRANSFORM with the DISTINCT/ALL clause.

## TRANSFORM_NON_HIVE

TRANSFORM with SERDE is only supported in hive mode.


