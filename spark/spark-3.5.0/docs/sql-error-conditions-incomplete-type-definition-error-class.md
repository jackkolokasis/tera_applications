---
layout: global
title: INCOMPLETE_TYPE_DEFINITION error class
displayTitle: INCOMPLETE_TYPE_DEFINITION error class
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

[SQLSTATE: 42K01](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

Incomplete complex type:

This error class has the following derived error classes:

## ARRAY

The definition of "ARRAY" type is incomplete. You must provide an element type. For example: "ARRAY`<elementType>`".

## MAP

The definition of "MAP" type is incomplete. You must provide a key type and a value type. For example: "MAP<TIMESTAMP, INT>".

## STRUCT

The definition of "STRUCT" type is incomplete. You must provide at least one field type. For example: "STRUCT<name STRING, phone DECIMAL(10, 0)>".


