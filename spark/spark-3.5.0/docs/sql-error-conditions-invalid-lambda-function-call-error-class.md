---
layout: global
title: INVALID_LAMBDA_FUNCTION_CALL error class
displayTitle: INVALID_LAMBDA_FUNCTION_CALL error class
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

Invalid lambda function call.

This error class has the following derived error classes:

## DUPLICATE_ARG_NAMES

The lambda function has duplicate arguments `<args>`. Please, consider to rename the argument names or set `<caseSensitiveConfig>` to "true".

## NON_HIGHER_ORDER_FUNCTION

A lambda function should only be used in a higher order function. However, its class is `<class>`, which is not a higher order function.

## NUM_ARGS_MISMATCH

A higher order function expects `<expectedNumArgs>` arguments, but got `<actualNumArgs>`.


