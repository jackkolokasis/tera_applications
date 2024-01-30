---
layout: global
title: CREATE_VIEW_COLUMN_ARITY_MISMATCH error class
displayTitle: CREATE_VIEW_COLUMN_ARITY_MISMATCH error class
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

[SQLSTATE: 21S01](sql-error-conditions-sqlstates.html#class-21-cardinality-violation)

Cannot create view `<viewName>`, the reason is

This error class has the following derived error classes:

## NOT_ENOUGH_DATA_COLUMNS

not enough data columns:
View columns: `<viewColumns>`.
Data columns: `<dataColumns>`.

## TOO_MANY_DATA_COLUMNS

too many data columns:
View columns: `<viewColumns>`.
Data columns: `<dataColumns>`.


