---
layout: global
title: INVALID_CURSOR error class
displayTitle: INVALID_CURSOR error class
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

[SQLSTATE: HY109](sql-error-conditions-sqlstates.html#class-HY-cli-specific-condition)

The cursor is invalid.

This error class has the following derived error classes:

## DISCONNECTED

The cursor has been disconnected by the server.

## NOT_REATTACHABLE

The cursor is not reattachable.

## POSITION_NOT_AVAILABLE

The cursor position id `<responseId>` is no longer available at index `<index>`.

## POSITION_NOT_FOUND

The cursor position id `<responseId>` is not found.


