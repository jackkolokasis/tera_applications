---
layout: global
title: INVALID_INLINE_TABLE error class
displayTitle: INVALID_INLINE_TABLE error class
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

Invalid inline table.

This error class has the following derived error classes:

## CANNOT_EVALUATE_EXPRESSION_IN_INLINE_TABLE

Cannot evaluate the expression `<expr>` in inline table definition.

## FAILED_SQL_EXPRESSION_EVALUATION

Failed to evaluate the SQL expression `<sqlExpr>`. Please check your syntax and ensure all required tables and columns are available.

## INCOMPATIBLE_TYPES_IN_INLINE_TABLE

Found incompatible types in the column `<colName>` for inline table.

## NUM_COLUMNS_MISMATCH

Inline table expected `<expectedNumCols>` columns but found `<actualNumCols>` columns in row `<rowIndex>`.


