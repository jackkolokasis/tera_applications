---
layout: global
title: DUPLICATE_ROUTINE_PARAMETER_ASSIGNMENT error class
displayTitle: DUPLICATE_ROUTINE_PARAMETER_ASSIGNMENT error class
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

[SQLSTATE: 4274K](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

Call to function `<functionName>` is invalid because it includes multiple argument assignments to the same parameter name `<parameterName>`.

This error class has the following derived error classes:

## BOTH_POSITIONAL_AND_NAMED

A positional argument and named argument both referred to the same parameter. Please remove the named argument referring to this parameter.

## DOUBLE_NAMED_ARGUMENT_REFERENCE

More than one named argument referred to the same parameter. Please assign a value only once.


