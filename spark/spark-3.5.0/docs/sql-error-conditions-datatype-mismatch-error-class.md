---
layout: global
title: DATATYPE_MISMATCH error class
displayTitle: DATATYPE_MISMATCH error class
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

[SQLSTATE: 42K09](sql-error-conditions-sqlstates.html#class-42-syntax-error-or-access-rule-violation)

Cannot resolve `<sqlExpr>` due to data type mismatch:

This error class has the following derived error classes:

## ARRAY_FUNCTION_DIFF_TYPES

Input to `<functionName>` should have been `<dataType>` followed by a value with same element type, but it's [`<leftType>`, `<rightType>`].

## BINARY_ARRAY_DIFF_TYPES

Input to function `<functionName>` should have been two `<arrayType>` with same element type, but it's [`<leftType>`, `<rightType>`].

## BINARY_OP_DIFF_TYPES

the left and right operands of the binary operator have incompatible types (`<left>` and `<right>`).

## BINARY_OP_WRONG_TYPE

the binary operator requires the input type `<inputType>`, not `<actualDataType>`.

## BLOOM_FILTER_BINARY_OP_WRONG_TYPE

The Bloom filter binary input to `<functionName>` should be either a constant value or a scalar subquery expression, but it's `<actual>`.

## BLOOM_FILTER_WRONG_TYPE

Input to function `<functionName>` should have been `<expectedLeft>` followed by value with `<expectedRight>`, but it's [`<actual>`].

## CANNOT_CONVERT_TO_JSON

Unable to convert column `<name>` of type `<type>` to JSON.

## CANNOT_DROP_ALL_FIELDS

Cannot drop all fields in struct.

## CAST_WITHOUT_SUGGESTION

cannot cast `<srcType>` to `<targetType>`.

## CAST_WITH_CONF_SUGGESTION

cannot cast `<srcType>` to `<targetType>` with ANSI mode on.
If you have to cast `<srcType>` to `<targetType>`, you can set `<config>` as `<configVal>`.

## CAST_WITH_FUNC_SUGGESTION

cannot cast `<srcType>` to `<targetType>`.
To convert values from `<srcType>` to `<targetType>`, you can use the functions `<functionNames>` instead.

## CREATE_MAP_KEY_DIFF_TYPES

The given keys of function `<functionName>` should all be the same type, but they are `<dataType>`.

## CREATE_MAP_VALUE_DIFF_TYPES

The given values of function `<functionName>` should all be the same type, but they are `<dataType>`.

## CREATE_NAMED_STRUCT_WITHOUT_FOLDABLE_STRING

Only foldable `STRING` expressions are allowed to appear at odd position, but they are `<inputExprs>`.

## DATA_DIFF_TYPES

Input to `<functionName>` should all be the same type, but it's `<dataType>`.

## FILTER_NOT_BOOLEAN

Filter expression `<filter>` of type `<type>` is not a boolean.

## HASH_MAP_TYPE

Input to the function `<functionName>` cannot contain elements of the "MAP" type. In Spark, same maps may have different hashcode, thus hash expressions are prohibited on "MAP" elements. To restore previous behavior set "spark.sql.legacy.allowHashOnMapType" to "true".

## INPUT_SIZE_NOT_ONE

Length of `<exprName>` should be 1.

## INVALID_ARG_VALUE

The `<inputName>` value must to be a `<requireType>` literal of `<validValues>`, but got `<inputValue>`.

## INVALID_JSON_MAP_KEY_TYPE

Input schema `<schema>` can only contain STRING as a key type for a MAP.

## INVALID_JSON_SCHEMA

Input schema `<schema>` must be a struct, an array or a map.

## INVALID_MAP_KEY_TYPE

The key of map cannot be/contain `<keyType>`.

## INVALID_ORDERING_TYPE

The `<functionName>` does not support ordering on type `<dataType>`.

## INVALID_ROW_LEVEL_OPERATION_ASSIGNMENTS

`<errors>`

## IN_SUBQUERY_DATA_TYPE_MISMATCH

The data type of one or more elements in the left hand side of an IN subquery is not compatible with the data type of the output of the subquery. Mismatched columns: [`<mismatchedColumns>`], left side: [`<leftType>`], right side: [`<rightType>`].

## IN_SUBQUERY_LENGTH_MISMATCH

The number of columns in the left hand side of an IN subquery does not match the number of columns in the output of subquery. Left hand side columns(length: `<leftLength>`): [`<leftColumns>`], right hand side columns(length: `<rightLength>`): [`<rightColumns>`].

## MAP_CONCAT_DIFF_TYPES

The `<functionName>` should all be of type map, but it's `<dataType>`.

## MAP_FUNCTION_DIFF_TYPES

Input to `<functionName>` should have been `<dataType>` followed by a value with same key type, but it's [`<leftType>`, `<rightType>`].

## MAP_ZIP_WITH_DIFF_TYPES

Input to the `<functionName>` should have been two maps with compatible key types, but it's [`<leftType>`, `<rightType>`].

## NON_FOLDABLE_INPUT

the input `<inputName>` should be a foldable `<inputType>` expression; however, got `<inputExpr>`.

## NON_STRING_TYPE

all arguments must be strings.

## NULL_TYPE

Null typed values cannot be used as arguments of `<functionName>`.

## PARAMETER_CONSTRAINT_VIOLATION

The `<leftExprName>`(`<leftExprValue>`) must be `<constraint>` the `<rightExprName>`(`<rightExprValue>`).

## RANGE_FRAME_INVALID_TYPE

The data type `<orderSpecType>` used in the order specification does not match the data type `<valueBoundaryType>` which is used in the range frame.

## RANGE_FRAME_MULTI_ORDER

A range window frame with value boundaries cannot be used in a window specification with multiple order by expressions: `<orderSpec>`.

## RANGE_FRAME_WITHOUT_ORDER

A range window frame cannot be used in an unordered window specification.

## SEQUENCE_WRONG_INPUT_TYPES

`<functionName>` uses the wrong parameter type. The parameter type must conform to:
1. The start and stop expressions must resolve to the same type.
2. If start and stop expressions resolve to the `<startType>` type, then the step expression must resolve to the `<stepType>` type.
3. Otherwise, if start and stop expressions resolve to the `<otherStartType>` type, then the step expression must resolve to the same type.

## SPECIFIED_WINDOW_FRAME_DIFF_TYPES

Window frame bounds `<lower>` and `<upper>` do not have the same type: `<lowerType>` <> `<upperType>`.

## SPECIFIED_WINDOW_FRAME_INVALID_BOUND

Window frame upper bound `<upper>` does not follow the lower bound `<lower>`.

## SPECIFIED_WINDOW_FRAME_UNACCEPTED_TYPE

The data type of the `<location>` bound `<exprType>` does not match the expected data type `<expectedType>`.

## SPECIFIED_WINDOW_FRAME_WITHOUT_FOLDABLE

Window frame `<location>` bound `<expression>` is not a literal.

## SPECIFIED_WINDOW_FRAME_WRONG_COMPARISON

The lower bound of a window frame must be `<comparison>` to the upper bound.

## STACK_COLUMN_DIFF_TYPES

The data type of the column (`<columnIndex>`) do not have the same type: `<leftType>` (`<leftParamIndex>`) <> `<rightType>` (`<rightParamIndex>`).

## TYPE_CHECK_FAILURE_WITH_HINT

`<msg>``<hint>`.

## UNEXPECTED_CLASS_TYPE

class `<className>` not found.

## UNEXPECTED_INPUT_TYPE

Parameter `<paramIndex>` requires the `<requiredType>` type, however `<inputSql>` has the type `<inputType>`.

## UNEXPECTED_NULL

The `<exprName>` must not be null.

## UNEXPECTED_RETURN_TYPE

The `<functionName>` requires return `<expectedType>` type, but the actual is `<actualType>` type.

## UNEXPECTED_STATIC_METHOD

cannot find a static method `<methodName>` that matches the argument types in `<className>`.

## UNSUPPORTED_INPUT_TYPE

The input of `<functionName>` can't be `<dataType>` type data.

## VALUE_OUT_OF_RANGE

The `<exprName>` must be between `<valueRange>` (current value = `<currentValue>`).

## WRONG_NUM_ARG_TYPES

The expression requires `<expectedNum>` argument types but the actual number is `<actualNum>`.

## WRONG_NUM_ENDPOINTS

The number of endpoints must be >= 2 to construct intervals but the actual number is `<actualNumber>`.


