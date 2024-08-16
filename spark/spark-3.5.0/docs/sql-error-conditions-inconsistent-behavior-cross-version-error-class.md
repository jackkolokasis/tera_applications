---
layout: global
title: INCONSISTENT_BEHAVIOR_CROSS_VERSION error class
displayTitle: INCONSISTENT_BEHAVIOR_CROSS_VERSION error class
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

[SQLSTATE: 42K0B](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

You may get a different result due to the upgrading to

This error class has the following derived error classes:

## DATETIME_PATTERN_RECOGNITION

Spark >= 3.0:
Fail to recognize `<pattern>` pattern in the DateTimeFormatter. 1) You can set `<config>` to "LEGACY" to restore the behavior before Spark 3.0. 2) You can form a valid datetime pattern with the guide from '`<docroot>`/sql-ref-datetime-pattern.html'.

## PARSE_DATETIME_BY_NEW_PARSER

Spark >= 3.0:
Fail to parse `<datetime>` in the new parser. You can set `<config>` to "LEGACY" to restore the behavior before Spark 3.0, or set to "CORRECTED" and treat it as an invalid datetime string.

## READ_ANCIENT_DATETIME

Spark >= 3.0:
reading dates before 1582-10-15 or timestamps before 1900-01-01T00:00:00Z
from `<format>` files can be ambiguous, as the files may be written by
Spark 2.x or legacy versions of Hive, which uses a legacy hybrid calendar
that is different from Spark 3.0+'s Proleptic Gregorian calendar.
See more details in SPARK-31404. You can set the SQL config `<config>` or
the datasource option `<option>` to "LEGACY" to rebase the datetime values
w.r.t. the calendar difference during reading. To read the datetime values
as it is, set the SQL config or the datasource option to "CORRECTED".

## WRITE_ANCIENT_DATETIME

Spark >= 3.0:
writing dates before 1582-10-15 or timestamps before 1900-01-01T00:00:00Z
into `<format>` files can be dangerous, as the files may be read by Spark 2.x
or legacy versions of Hive later, which uses a legacy hybrid calendar that
is different from Spark 3.0+'s Proleptic Gregorian calendar. See more
details in SPARK-31404. You can set `<config>` to "LEGACY" to rebase the
datetime values w.r.t. the calendar difference during writing, to get maximum
interoperability. Or set the config to "CORRECTED" to write the datetime
values as it is, if you are sure that the written files will only be read by
Spark 3.0+ or other systems that use Proleptic Gregorian calendar.


