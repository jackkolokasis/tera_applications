---
layout: global
title: NOT_A_CONSTANT_STRING error class
displayTitle: NOT_A_CONSTANT_STRING error class
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

[SQLSTATE: 42601](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

The expression `<expr>` used for the routine or clause `<name>` must be a constant STRING which is NOT NULL.

This error class has the following derived error classes:

## NOT_CONSTANT

To be considered constant the expression must not depend on any columns, contain a subquery, or invoke a non deterministic function such as rand().

## NULL

The expression evaluates to NULL.

## WRONG_TYPE

The data type of the expression is `<dataType>`.


