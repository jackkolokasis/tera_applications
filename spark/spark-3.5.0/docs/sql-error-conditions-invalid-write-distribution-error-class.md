---
layout: global
title: INVALID_WRITE_DISTRIBUTION error class
displayTitle: INVALID_WRITE_DISTRIBUTION error class
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

The requested write distribution is invalid.

This error class has the following derived error classes:

## PARTITION_NUM_AND_SIZE

The partition number and advisory partition size can't be specified at the same time.

## PARTITION_NUM_WITH_UNSPECIFIED_DISTRIBUTION

The number of partitions can't be specified with unspecified distribution.

## PARTITION_SIZE_WITH_UNSPECIFIED_DISTRIBUTION

The advisory partition size can't be specified with unspecified distribution.


