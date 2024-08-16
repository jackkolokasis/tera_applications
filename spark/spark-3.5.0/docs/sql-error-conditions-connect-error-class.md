---
layout: global
title: CONNECT error class
displayTitle: CONNECT error class
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

Generic Spark Connect error.

This error class has the following derived error classes:

## INTERCEPTOR_CTOR_MISSING

Cannot instantiate GRPC interceptor because `<cls>` is missing a default constructor without arguments.

## INTERCEPTOR_RUNTIME_ERROR

Error instantiating GRPC interceptor: `<msg>`

## PLUGIN_CTOR_MISSING

Cannot instantiate Spark Connect plugin because `<cls>` is missing a default constructor without arguments.

## PLUGIN_RUNTIME_ERROR

Error instantiating Spark Connect plugin: `<msg>`

## SESSION_NOT_SAME

Both Datasets must belong to the same SparkSession.


