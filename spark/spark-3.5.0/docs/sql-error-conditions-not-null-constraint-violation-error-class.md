---
layout: global
title: NOT_NULL_CONSTRAINT_VIOLATION error class
displayTitle: NOT_NULL_CONSTRAINT_VIOLATION error class
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

[SQLSTATE: 42000](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

Assigning a NULL is not allowed here.

This error class has the following derived error classes:

## ARRAY_ELEMENT

The array `<columnPath>` is defined to contain only elements that are NOT NULL.

## MAP_VALUE

The map `<columnPath>` is defined to contain only values that are NOT NULL.


