---
layout: global
title: INVALID_FORMAT error class
displayTitle: INVALID_FORMAT error class
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

The format is invalid: `<format>`.

This error class has the following derived error classes:

## CONT_THOUSANDS_SEPS

Thousands separators (, or G) must have digits in between them in the number format.

## CUR_MUST_BEFORE_DEC

Currency characters must appear before any decimal point in the number format.

## CUR_MUST_BEFORE_DIGIT

Currency characters must appear before digits in the number format.

## EMPTY

The number format string cannot be empty.

## ESC_AT_THE_END

The escape character is not allowed to end with.

## ESC_IN_THE_MIDDLE

The escape character is not allowed to precede `<char>`.

## MISMATCH_INPUT

The input `<inputType>` `<input>` does not match the format.

## THOUSANDS_SEPS_MUST_BEFORE_DEC

Thousands separators (, or G) may not appear after the decimal point in the number format.

## UNEXPECTED_TOKEN

Found the unexpected `<token>` in the format string; the structure of the format string must match: `[MI|S]` `[$]` `[0|9|G|,]*` `[.|D]` `[0|9]*` `[$]` `[PR|MI|S]`.

## WRONG_NUM_DIGIT

The format string requires at least one number digit.

## WRONG_NUM_TOKEN

At most one `<token>` is allowed in the number format.


