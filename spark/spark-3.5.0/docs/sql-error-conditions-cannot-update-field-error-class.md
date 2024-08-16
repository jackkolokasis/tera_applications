---
layout: global
title: CANNOT_UPDATE_FIELD error class
displayTitle: CANNOT_UPDATE_FIELD error class
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

Cannot update `<table>` field `<fieldName>` type:

This error class has the following derived error classes:

## ARRAY_TYPE

Update the element by updating `<fieldName>`.element.

## INTERVAL_TYPE

Update an interval by updating its fields.

## MAP_TYPE

Update a map by updating `<fieldName>`.key or `<fieldName>`.value.

## STRUCT_TYPE

Update a struct by updating its fields.

## USER_DEFINED_TYPE

Update a UserDefinedType[`<udtSql>`] by updating its fields.


