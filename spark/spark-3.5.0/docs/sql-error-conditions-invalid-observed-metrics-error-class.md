---
layout: global
title: INVALID_OBSERVED_METRICS error class
displayTitle: INVALID_OBSERVED_METRICS error class
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

SQLSTATE: none assigned

Invalid observed metrics.

This error class has the following derived error classes:

## AGGREGATE_EXPRESSION_WITH_DISTINCT_UNSUPPORTED

Aggregate expression with distinct are not allowed in observed metrics, but found: `<expr>`.

## AGGREGATE_EXPRESSION_WITH_FILTER_UNSUPPORTED

Aggregate expression with filter predicate are not allowed in observed metrics, but found: `<expr>`.

## MISSING_NAME

The observed metrics should be named: `<operator>`.

## NESTED_AGGREGATES_UNSUPPORTED

Nested aggregates are not allowed in observed metrics, but found: `<expr>`.

## NON_AGGREGATE_FUNC_ARG_IS_ATTRIBUTE

Attribute `<expr>` can only be used as an argument to an aggregate function.

## NON_AGGREGATE_FUNC_ARG_IS_NON_DETERMINISTIC

Non-deterministic expression `<expr>` can only be used as an argument to an aggregate function.

## WINDOW_EXPRESSIONS_UNSUPPORTED

Window expressions are not allowed in observed metrics, but found: `<expr>`.


