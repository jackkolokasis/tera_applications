---
layout: global
title: UNSUPPORTED_SUBQUERY_EXPRESSION_CATEGORY error class
displayTitle: UNSUPPORTED_SUBQUERY_EXPRESSION_CATEGORY error class
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

Unsupported subquery expression:

This error class has the following derived error classes:

## ACCESSING_OUTER_QUERY_COLUMN_IS_NOT_ALLOWED

Accessing outer query column is not allowed in this location`<treeNode>`.

## AGGREGATE_FUNCTION_MIXED_OUTER_LOCAL_REFERENCES

Found an aggregate function in a correlated predicate that has both outer and local references, which is not supported: `<function>`.

## CORRELATED_COLUMN_IS_NOT_ALLOWED_IN_PREDICATE

Correlated column is not allowed in predicate: `<treeNode>`.

## CORRELATED_COLUMN_NOT_FOUND

A correlated outer name reference within a subquery expression body was not found in the enclosing query: `<value>`.

## CORRELATED_REFERENCE

Expressions referencing the outer query are not supported outside of WHERE/HAVING clauses: `<sqlExprs>`.

## LATERAL_JOIN_CONDITION_NON_DETERMINISTIC

Lateral join condition cannot be non-deterministic: `<condition>`.

## MUST_AGGREGATE_CORRELATED_SCALAR_SUBQUERY

Correlated scalar subqueries must be aggregated to return at most one row.

## NON_CORRELATED_COLUMNS_IN_GROUP_BY

A GROUP BY clause in a scalar correlated subquery cannot contain non-correlated columns: `<value>`.

## NON_DETERMINISTIC_LATERAL_SUBQUERIES

Non-deterministic lateral subqueries are not supported when joining with outer relations that produce more than one row`<treeNode>`.

## UNSUPPORTED_CORRELATED_REFERENCE_DATA_TYPE

Correlated column reference '`<expr>`' cannot be `<dataType>` type.

## UNSUPPORTED_CORRELATED_SCALAR_SUBQUERY

Correlated scalar subqueries can only be used in filters, aggregations, projections, and UPDATE/MERGE/DELETE commands`<treeNode>`.

## UNSUPPORTED_IN_EXISTS_SUBQUERY

IN/EXISTS predicate subqueries can only be used in filters, joins, aggregations, window functions, projections, and UPDATE/MERGE/DELETE commands`<treeNode>`.


