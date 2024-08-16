/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.sql.errors

import java.io.{FileNotFoundException, IOException}
import java.lang.reflect.InvocationTargetException
import java.net.{URISyntaxException, URL}
import java.time.DateTimeException
import java.util.concurrent.TimeoutException

import com.fasterxml.jackson.core.{JsonParser, JsonToken}
import org.apache.hadoop.fs.{FileAlreadyExistsException, FileStatus, Path}
import org.apache.hadoop.fs.permission.FsPermission
import org.codehaus.commons.compiler.{CompileException, InternalCompilerException}

import org.apache.spark._
import org.apache.spark.launcher.SparkLauncher
import org.apache.spark.memory.SparkOutOfMemoryError
import org.apache.spark.sql.AnalysisException
import org.apache.spark.sql.catalyst.ScalaReflection.Schema
import org.apache.spark.sql.catalyst.TableIdentifier
import org.apache.spark.sql.catalyst.analysis.UnresolvedGenerator
import org.apache.spark.sql.catalyst.catalog.{CatalogDatabase, CatalogTable}
import org.apache.spark.sql.catalyst.expressions.{AttributeReference, Expression}
import org.apache.spark.sql.catalyst.parser.ParseException
import org.apache.spark.sql.catalyst.plans.JoinType
import org.apache.spark.sql.catalyst.plans.logical.LogicalPlan
import org.apache.spark.sql.catalyst.plans.logical.statsEstimation.ValueInterval
import org.apache.spark.sql.catalyst.trees.{Origin, SQLQueryContext, TreeNode}
import org.apache.spark.sql.catalyst.util.{sideBySide, BadRecordException, DateTimeUtils, FailFastMode}
import org.apache.spark.sql.connector.catalog.{CatalogNotFoundException, Table, TableProvider}
import org.apache.spark.sql.connector.catalog.CatalogV2Implicits._
import org.apache.spark.sql.connector.expressions.Transform
import org.apache.spark.sql.internal.SQLConf
import org.apache.spark.sql.internal.StaticSQLConf.GLOBAL_TEMP_DATABASE
import org.apache.spark.sql.streaming.OutputMode
import org.apache.spark.sql.types._
import org.apache.spark.unsafe.array.ByteArrayMethods
import org.apache.spark.unsafe.types.UTF8String
import org.apache.spark.util.{CircularBuffer, Utils}

/**
 * Object for grouping error messages from (most) exceptions thrown during query execution.
 * This does not include exceptions thrown during the eager execution of commands, which are
 * grouped into [[QueryCompilationErrors]].
 */
private[sql] object QueryExecutionErrors extends QueryErrorsBase with ExecutionErrors {

  def cannotEvaluateExpressionError(expression: Expression): Throwable = {
    SparkException.internalError(s"Cannot evaluate expression: $expression")
  }

  def cannotGenerateCodeForExpressionError(expression: Expression): Throwable = {
    SparkException.internalError(s"Cannot generate code for expression: $expression")
  }

  def cannotTerminateGeneratorError(generator: UnresolvedGenerator): Throwable = {
    SparkException.internalError(s"Cannot terminate expression: $generator")
  }

  def castingCauseOverflowError(t: Any, from: DataType, to: DataType): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "CAST_OVERFLOW",
      messageParameters = Map(
        "value" -> toSQLValue(t, from),
        "sourceType" -> toSQLType(from),
        "targetType" -> toSQLType(to),
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = Array.empty,
      summary = "")
  }

  def castingCauseOverflowErrorInTableInsert(
      from: DataType,
      to: DataType,
      columnName: String): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "CAST_OVERFLOW_IN_TABLE_INSERT",
      messageParameters = Map(
        "sourceType" -> toSQLType(from),
        "targetType" -> toSQLType(to),
        "columnName" -> toSQLId(columnName)),
      context = Array.empty,
      summary = ""
    )
  }

  def cannotChangeDecimalPrecisionError(
      value: Decimal,
      decimalPrecision: Int,
      decimalScale: Int,
      context: SQLQueryContext = null): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "NUMERIC_VALUE_OUT_OF_RANGE",
      messageParameters = Map(
        "value" -> value.toPlainString,
        "precision" -> decimalPrecision.toString,
        "scale" -> decimalScale.toString,
        "config" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidInputSyntaxForBooleanError(
      s: UTF8String,
      context: SQLQueryContext): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "CAST_INVALID_INPUT",
      messageParameters = Map(
        "expression" -> toSQLValue(s, StringType),
        "sourceType" -> toSQLType(StringType),
        "targetType" -> toSQLType(BooleanType),
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidInputInCastToNumberError(
      to: DataType,
      s: UTF8String,
      context: SQLQueryContext): SparkNumberFormatException = {
    new SparkNumberFormatException(
      errorClass = "CAST_INVALID_INPUT",
      messageParameters = Map(
        "expression" -> toSQLValue(s, StringType),
        "sourceType" -> toSQLType(StringType),
        "targetType" -> toSQLType(to),
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidInputInConversionError(
      to: DataType,
      s: UTF8String,
      fmt: UTF8String,
      hint: String): SparkIllegalArgumentException = {
      new SparkIllegalArgumentException(
        errorClass = "CONVERSION_INVALID_INPUT",
        messageParameters = Map(
          "str" -> toSQLValue(s, StringType),
          "fmt" -> toSQLValue(fmt, StringType),
          "targetType" -> toSQLType(to),
          "suggestion" -> toSQLId(hint)))
  }

  def cannotCastFromNullTypeError(to: DataType): Throwable = {
    new SparkException(
      errorClass = "CANNOT_CAST_DATATYPE",
      messageParameters = Map(
        "sourceType" -> NullType.typeName,
        "targetType" -> to.typeName),
      cause = null)
  }

  def cannotCastError(from: DataType, to: DataType): Throwable = {
    new SparkException(
      errorClass = "CANNOT_CAST_DATATYPE",
      messageParameters = Map(
        "sourceType" -> from.typeName,
        "targetType" -> to.typeName),
      cause = null)
  }

  def cannotParseDecimalError(): Throwable = {
    new SparkRuntimeException(
      errorClass = "CANNOT_PARSE_DECIMAL",
      messageParameters = Map.empty)
  }

  def dataTypeUnsupportedError(dataType: String, failure: String): Throwable = {
    DataTypeErrors.dataTypeUnsupportedError(dataType, failure)
  }

  def failedExecuteUserDefinedFunctionError(functionName: String, inputTypes: String,
      outputType: String, e: Throwable): Throwable = {
    new SparkException(
      errorClass = "FAILED_EXECUTE_UDF",
      messageParameters = Map(
        "functionName" -> toSQLId(functionName),
        "signature" -> inputTypes,
        "result" -> outputType),
      cause = e)
  }

  def divideByZeroError(context: SQLQueryContext): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "DIVIDE_BY_ZERO",
      messageParameters = Map("config" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def intervalDividedByZeroError(context: SQLQueryContext): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "INTERVAL_DIVIDED_BY_ZERO",
      messageParameters = Map.empty,
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidArrayIndexError(
      index: Int,
      numElements: Int,
      context: SQLQueryContext): ArrayIndexOutOfBoundsException = {
    new SparkArrayIndexOutOfBoundsException(
      errorClass = "INVALID_ARRAY_INDEX",
      messageParameters = Map(
        "indexValue" -> toSQLValue(index, IntegerType),
        "arraySize" -> toSQLValue(numElements, IntegerType),
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidElementAtIndexError(
      index: Int,
      numElements: Int,
      context: SQLQueryContext): ArrayIndexOutOfBoundsException = {
    new SparkArrayIndexOutOfBoundsException(
      errorClass = "INVALID_ARRAY_INDEX_IN_ELEMENT_AT",
      messageParameters = Map(
        "indexValue" -> toSQLValue(index, IntegerType),
        "arraySize" -> toSQLValue(numElements, IntegerType),
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def invalidBitmapPositionError(bitPosition: Long,
                                 bitmapNumBytes: Long): ArrayIndexOutOfBoundsException = {
    new SparkArrayIndexOutOfBoundsException(
      errorClass = "INVALID_BITMAP_POSITION",
      messageParameters = Map(
        "bitPosition" -> s"$bitPosition",
        "bitmapNumBytes" -> s"$bitmapNumBytes",
        "bitmapNumBits" -> s"${bitmapNumBytes * 8}"),
      context = Array.empty,
      summary = "")
  }

  def invalidFractionOfSecondError(): DateTimeException = {
    new SparkDateTimeException(
      errorClass = "INVALID_FRACTION_OF_SECOND",
      messageParameters = Map(
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)
      ),
      context = Array.empty,
      summary = "")
  }

  def ansiDateTimeParseError(e: Exception): SparkDateTimeException = {
    new SparkDateTimeException(
      errorClass = "CANNOT_PARSE_TIMESTAMP",
      messageParameters = Map(
        "message" -> e.getMessage,
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = Array.empty,
      summary = "")
  }

  def ansiDateTimeError(e: Exception): SparkDateTimeException = {
    new SparkDateTimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2000",
      messageParameters = Map(
        "message" -> e.getMessage,
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = Array.empty,
      summary = "")
  }

  def ansiIllegalArgumentError(message: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2000",
      messageParameters = Map(
        "message" -> message,
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)))
  }

  def ansiIllegalArgumentError(e: IllegalArgumentException): IllegalArgumentException = {
    ansiIllegalArgumentError(e.getMessage)
  }

  def overflowInSumOfDecimalError(context: SQLQueryContext): ArithmeticException = {
    arithmeticOverflowError("Overflow in sum of decimals", context = context)
  }

  def overflowInIntegralDivideError(context: SQLQueryContext): ArithmeticException = {
    arithmeticOverflowError("Overflow in integral divide", "try_divide", context)
  }

  def overflowInConvError(context: SQLQueryContext): ArithmeticException = {
    arithmeticOverflowError("Overflow in function conv()", context = context)
  }

  def mapSizeExceedArraySizeWhenZipMapError(size: Int): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2003",
      messageParameters = Map(
        "size" -> size.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def literalTypeUnsupportedError(v: Any): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "UNSUPPORTED_FEATURE.LITERAL_TYPE",
      messageParameters = Map(
        "value" -> v.toString,
        "type" ->  v.getClass.toString))
  }

  def pivotColumnUnsupportedError(v: Any, dataType: DataType): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "UNSUPPORTED_FEATURE.PIVOT_TYPE",
      messageParameters = Map(
        "value" -> v.toString,
        "type" ->  toSQLType(dataType)))
  }

  def noDefaultForDataTypeError(dataType: DataType): SparkException = {
    SparkException.internalError(s"No default value for type: ${toSQLType(dataType)}.")
  }

  def orderedOperationUnsupportedByDataTypeError(
      dataType: DataType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2005",
      messageParameters = Map("dataType" -> dataType.toString()))
  }

  def orderedOperationUnsupportedByDataTypeError(
      dataType: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2005",
      messageParameters = Map("dataType" -> dataType))
  }

  def invalidRegexGroupIndexError(
      funcName: String,
      groupCount: Int,
      groupIndex: Int): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_PARAMETER_VALUE.REGEX_GROUP_INDEX",
      messageParameters = Map(
        "parameter" -> toSQLId("idx"),
        "functionName" -> toSQLId(funcName),
        "groupCount" -> groupCount.toString(),
        "groupIndex" -> groupIndex.toString()))
  }

  def invalidUrlError(url: UTF8String, e: URISyntaxException): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "INVALID_URL",
      messageParameters = Map(
        "url" -> url.toString,
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      cause = e)
  }

  def illegalUrlError(url: UTF8String): Throwable = {
    new SparkIllegalArgumentException(
      errorClass = "CANNOT_DECODE_URL",
      messageParameters = Map("url" -> url.toString)
    )
  }

  def mergeUnsupportedByWindowFunctionError(funcName: String): Throwable = {
    SparkException.internalError(
      s"The aggregate window function ${toSQLId(funcName)} does not support merging.")
  }

  def dataTypeUnexpectedError(dataType: DataType): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2011",
      messageParameters = Map("dataType" -> dataType.catalogString))
  }

  def typeUnsupportedError(dataType: DataType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2011",
      messageParameters = Map("dataType" -> dataType.toString()))
  }

  def negativeValueUnexpectedError(
      frequencyExpression : Expression): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2013",
      messageParameters = Map("frequencyExpression" -> frequencyExpression.sql))
  }

  def addNewFunctionMismatchedWithFunctionError(funcName: String): Throwable = {
    SparkException.internalError(
      "Cannot add new function to generated class, " +
        s"failed to match ${toSQLId(funcName)} at `addNewFunction`.")
  }

  def cannotGenerateCodeForIncomparableTypeError(
      codeType: String, dataType: DataType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2015",
      messageParameters = Map(
        "codeType" -> codeType,
        "dataType" -> dataType.catalogString))
  }

  def cannotInterpolateClassIntoCodeBlockError(arg: Any): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2016",
      messageParameters = Map("arg" -> arg.getClass.getName))
  }

  def customCollectionClsNotResolvedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2017",
      messageParameters = Map.empty)
  }

  def classUnsupportedByMapObjectsError(cls: Class[_]): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2018",
      messageParameters = Map("cls" -> cls.getName))
  }

  def nullAsMapKeyNotAllowedError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "NULL_MAP_KEY",
      messageParameters = Map.empty)
  }

  def methodNotDeclaredError(name: String): Throwable = {
    SparkException.internalError(
      s"""A method named "$name" is not declared in any enclosing class nor any supertype""")
  }

  def methodNotFoundError(
      cls: Class[_],
      functionName: String,
      argClasses: Seq[Class[_]]): Throwable = {
    SparkException.internalError(
      s"Couldn't find method $functionName with arguments " +
        s"${argClasses.mkString("(", ", ", ")")} on $cls.")
  }

  def constructorNotFoundError(cls: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2020",
      messageParameters = Map("cls" -> cls))
  }

  def unsupportedNaturalJoinTypeError(joinType: JoinType): SparkException = {
    SparkException.internalError(
      s"Unsupported natural join type ${joinType.toString}")
  }

  def notExpectedUnresolvedEncoderError(attr: AttributeReference): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2023",
      messageParameters = Map("attr" -> attr.toString()))
  }

  def unsupportedEncoderError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2024",
      messageParameters = Map.empty)
  }

  def notOverrideExpectedMethodsError(
      className: String, m1: String, m2: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2025",
      messageParameters = Map("className" -> className, "m1" -> m1, "m2" -> m2))
  }

  def failToConvertValueToJsonError(
      value: AnyRef, cls: Class[_], dataType: DataType): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2026",
      messageParameters = Map(
        "value" -> value.toString(),
        "cls" -> cls.toString(),
        "dataType" -> dataType.toString()))
  }

  def unexpectedOperatorInCorrelatedSubquery(
      op: LogicalPlan, pos: String = ""): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2027",
      messageParameters = Map("op" -> op.toString(), "pos" -> pos))
  }

  def unsupportedRoundingMode(roundMode: BigDecimal.RoundingMode.Value): SparkException = {
    DataTypeErrors.unsupportedRoundingMode(roundMode)
  }

  def resolveCannotHandleNestedSchema(plan: LogicalPlan): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2030",
      messageParameters = Map("plan" -> plan.toString()))
  }

  def inputExternalRowCannotBeNullError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2031",
      messageParameters = Map.empty)
  }

  def fieldCannotBeNullMsg(index: Int, fieldName: String): String = {
    s"The ${index}th field '$fieldName' of input row cannot be null."
  }

  def fieldCannotBeNullError(index: Int, fieldName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2032",
      messageParameters = Map("fieldCannotBeNullMsg" -> fieldCannotBeNullMsg(index, fieldName)))
  }

  def unableToCreateDatabaseAsFailedToCreateDirectoryError(
      dbDefinition: CatalogDatabase, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2033",
      messageParameters = Map(
        "name" -> dbDefinition.name,
        "locationUri" -> dbDefinition.locationUri.toString()),
      cause = e)
  }

  def unableToDropDatabaseAsFailedToDeleteDirectoryError(
      dbDefinition: CatalogDatabase, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2034",
      messageParameters = Map(
        "name" -> dbDefinition.name,
        "locationUri" -> dbDefinition.locationUri.toString()),
      cause = e)
  }

  def unableToCreateTableAsFailedToCreateDirectoryError(
      table: String, defaultTableLocation: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2035",
      messageParameters = Map(
        "table" -> table,
        "defaultTableLocation" -> defaultTableLocation.toString()),
      cause = e)
  }

  def unableToDeletePartitionPathError(partitionPath: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2036",
      messageParameters = Map("partitionPath" -> partitionPath.toString()),
      cause = e)
  }

  def unableToDropTableAsFailedToDeleteDirectoryError(
      table: String, dir: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2037",
      messageParameters = Map("table" -> table, "dir" -> dir.toString()),
      cause = e)
  }

  def unableToRenameTableAsFailedToRenameDirectoryError(
      oldName: String, newName: String, oldDir: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2038",
      messageParameters = Map(
        "oldName" -> oldName,
        "newName" -> newName,
        "oldDir" -> oldDir.toString()),
      cause = e)
  }

  def unableToCreatePartitionPathError(partitionPath: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2039",
      messageParameters = Map("partitionPath" -> partitionPath.toString()),
      cause = e)
  }

  def unableToRenamePartitionPathError(oldPartPath: Path, e: IOException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2040",
      messageParameters = Map("oldPartPath" -> oldPartPath.toString()),
      cause = e)
  }

  def methodNotImplementedError(methodName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2041",
      messageParameters = Map("methodName" -> methodName))
  }

  def arithmeticOverflowError(e: ArithmeticException): SparkArithmeticException = {
    new SparkArithmeticException(
      errorClass = "_LEGACY_ERROR_TEMP_2042",
      messageParameters = Map(
        "message" -> e.getMessage,
        "ansiConfig" -> toSQLConf(SQLConf.ANSI_ENABLED.key)),
      context = Array.empty,
      summary = "")
  }

  def unaryMinusCauseOverflowError(originValue: Int): SparkArithmeticException = {
    new SparkArithmeticException(
      errorClass = "_LEGACY_ERROR_TEMP_2043",
      messageParameters = Map("sqlValue" -> toSQLValue(originValue, IntegerType)),
      context = Array.empty,
      summary = "")
  }

  def binaryArithmeticCauseOverflowError(
      eval1: Short, symbol: String, eval2: Short): SparkArithmeticException = {
    new SparkArithmeticException(
      errorClass = "BINARY_ARITHMETIC_OVERFLOW",
      messageParameters = Map(
        "value1" -> toSQLValue(eval1, ShortType),
        "symbol" -> symbol,
        "value2" -> toSQLValue(eval2, ShortType)),
      context = Array.empty,
      summary = "")
  }

  def intervalArithmeticOverflowError(
      message: String,
      hint: String = "",
      context: SQLQueryContext): ArithmeticException = {
    val alternative = if (hint.nonEmpty) {
      s" Use '$hint' to tolerate overflow and return NULL instead."
    } else ""
    new SparkArithmeticException(
      errorClass = "INTERVAL_ARITHMETIC_OVERFLOW",
      messageParameters = Map(
        "message" -> message,
        "alternative" -> alternative),
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def failedToCompileMsg(e: Exception): String = {
    s"failed to compile: $e"
  }

  def internalCompilerError(e: InternalCompilerException): Throwable = {
    new InternalCompilerException(failedToCompileMsg(e), e)
  }

  def compilerError(e: CompileException): Throwable = {
    new CompileException(failedToCompileMsg(e), e.getLocation)
  }

  def unsupportedTableChangeError(e: IllegalArgumentException): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2045",
      messageParameters = Map("message" -> e.getMessage),
      cause = e)
  }

  def notADatasourceRDDPartitionError(split: Partition): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2046",
      messageParameters = Map("split" -> split.toString()),
      cause = null)
  }

  def dataPathNotSpecifiedError(): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2047",
      messageParameters = Map.empty)
  }

  def createStreamingSourceNotSpecifySchemaError(): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2048",
      messageParameters = Map.empty)
  }

  def streamedOperatorUnsupportedByDataSourceError(
      className: String, operator: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2049",
      messageParameters = Map("className" -> className, "operator" -> operator))
  }

  def nonTimeWindowNotSupportedInStreamingError(
      windowFuncList: Seq[String],
      columnNameList: Seq[String],
      windowSpecList: Seq[String],
      origin: Origin): AnalysisException = {
    new AnalysisException(
      errorClass = "NON_TIME_WINDOW_NOT_SUPPORTED_IN_STREAMING",
      messageParameters = Map(
        "windowFunc" -> windowFuncList.map(toSQLStmt(_)).mkString(","),
        "columnName" -> columnNameList.map(toSQLId(_)).mkString(","),
        "windowSpec" -> windowSpecList.map(toSQLStmt(_)).mkString(",")),
        origin = origin)
  }

  def multiplePathsSpecifiedError(allPaths: Seq[String]): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2050",
      messageParameters = Map("paths" -> allPaths.mkString(", ")))
  }

  def dataSourceNotFoundError(
      provider: String, error: Throwable): SparkClassNotFoundException = {
    new SparkClassNotFoundException(
      errorClass = "DATA_SOURCE_NOT_FOUND",
      messageParameters = Map("provider" -> provider),
      cause = error)
  }

  def removedClassInSpark2Error(className: String, e: Throwable): SparkClassNotFoundException = {
    new SparkClassNotFoundException(
      errorClass = "_LEGACY_ERROR_TEMP_2052",
      messageParameters = Map("className" -> className),
      cause = e)
  }

  def incompatibleDataSourceRegisterError(e: Throwable): Throwable = {
    new SparkClassNotFoundException(
      errorClass = "INCOMPATIBLE_DATASOURCE_REGISTER",
      messageParameters = Map("message" -> e.getMessage),
      cause = e)
  }

  def sparkUpgradeInReadingDatesError(
      format: String, config: String, option: String): SparkUpgradeException = {
    new SparkUpgradeException(
      errorClass = "INCONSISTENT_BEHAVIOR_CROSS_VERSION.READ_ANCIENT_DATETIME",
      messageParameters = Map(
        "format" -> format,
        "config" -> toSQLConf(config),
        "option" -> toDSOption(option)),
      cause = null
    )
  }

  def sparkUpgradeInWritingDatesError(format: String, config: String): SparkUpgradeException = {
    new SparkUpgradeException(
      errorClass = "INCONSISTENT_BEHAVIOR_CROSS_VERSION.WRITE_ANCIENT_DATETIME",
      messageParameters = Map(
        "format" -> format,
        "config" -> toSQLConf(config)),
      cause = null
    )
  }

  def buildReaderUnsupportedForFileFormatError(
      format: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2053",
      messageParameters = Map("format" -> format))
  }

  def taskFailedWhileWritingRowsError(path: String, cause: Throwable): Throwable = {
    new SparkException(
      errorClass = "TASK_WRITE_FAILED",
      messageParameters = Map("path" -> path),
      cause = cause)
  }

  def readCurrentFileNotFoundError(e: FileNotFoundException): SparkFileNotFoundException = {
    new SparkFileNotFoundException(
      errorClass = "_LEGACY_ERROR_TEMP_2055",
      messageParameters = Map("message" -> e.getMessage))
  }

  def saveModeUnsupportedError(saveMode: Any, pathExists: Boolean): Throwable = {
    val errorSubClass = if (pathExists) "EXISTENT_PATH" else "NON_EXISTENT_PATH"
    new SparkIllegalArgumentException(
      errorClass = s"UNSUPPORTED_SAVE_MODE.$errorSubClass",
      messageParameters = Map("saveMode" -> toSQLValue(saveMode, StringType)))
  }

  def cannotClearOutputDirectoryError(staticPrefixPath: Path): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2056",
      messageParameters = Map("staticPrefixPath" -> staticPrefixPath.toString()),
      cause = null)
  }

  def cannotClearPartitionDirectoryError(path: Path): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2057",
      messageParameters = Map("path" -> path.toString()),
      cause = null)
  }

  def failedToCastValueToDataTypeForPartitionColumnError(
      value: String, dataType: DataType, columnName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2058",
      messageParameters = Map(
        "value" -> value,
        "dataType" -> dataType.toString(),
        "columnName" -> columnName))
  }

  def endOfStreamError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2059",
      messageParameters = Map.empty,
      cause = null)
  }

  def fallbackV1RelationReportsInconsistentSchemaError(
      v2Schema: StructType, v1Schema: StructType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2060",
      messageParameters = Map("v2Schema" -> v2Schema.toString(), "v1Schema" -> v1Schema.toString()))
  }

  def noRecordsFromEmptyDataReaderError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2061",
      messageParameters = Map.empty,
      cause = null)
  }

  def fileNotFoundError(e: FileNotFoundException): SparkFileNotFoundException = {
    new SparkFileNotFoundException(
      errorClass = "_LEGACY_ERROR_TEMP_2062",
      messageParameters = Map("message" -> e.getMessage))
  }

  def unsupportedSchemaColumnConvertError(
      filePath: String,
      column: String,
      logicalType: String,
      physicalType: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2063",
      messageParameters = Map(
        "filePath" -> filePath,
        "column" -> column,
        "logicalType" -> logicalType,
        "physicalType" -> physicalType),
      cause = e)
  }

  def cannotReadFilesError(
      e: Throwable,
      path: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2064",
      messageParameters = Map("path" -> path),
      cause = e)
  }

  def cannotCreateColumnarReaderError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2065",
      messageParameters = Map.empty,
      cause = null)
  }

  def invalidNamespaceNameError(namespace: Array[String]): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2066",
      messageParameters = Map("namespace" -> namespace.quoted))
  }

  def unsupportedPartitionTransformError(
      transform: Transform): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2067",
      messageParameters = Map("transform" -> transform.toString()))
  }

  def missingDatabaseLocationError(): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2068",
      messageParameters = Map.empty)
  }

  def cannotRemoveReservedPropertyError(property: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2069",
      messageParameters = Map("property" -> property))
  }

  def writingJobFailedError(cause: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2070",
      messageParameters = Map.empty,
      cause = cause)
  }

  def commitDeniedError(
      partId: Int, taskId: Long, attemptId: Int, stageId: Int, stageAttempt: Int): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2071",
      messageParameters = Map(
        "partId" -> partId.toString(),
        "taskId" -> taskId.toString(),
        "attemptId" -> attemptId.toString(),
        "stageId" -> stageId.toString(),
        "stageAttempt" -> stageAttempt.toString()),
      cause = null)
  }

  def cannotCreateJDBCTableWithPartitionsError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2073",
      messageParameters = Map.empty)
  }

  def unsupportedUserSpecifiedSchemaError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2074",
      messageParameters = Map.empty)
  }

  def writeUnsupportedForBinaryFileDataSourceError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2075",
      messageParameters = Map.empty)
  }

  def fileLengthExceedsMaxLengthError(status: FileStatus, maxLength: Int): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2076",
      messageParameters = Map(
        "path" -> status.getPath.toString(),
        "len" -> status.getLen.toString(),
        "maxLength" -> maxLength.toString()),
      cause = null)
  }

  def unsupportedFieldNameError(fieldName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2077",
      messageParameters = Map("fieldName" -> fieldName))
  }

  def cannotSpecifyBothJdbcTableNameAndQueryError(
      jdbcTableName: String, jdbcQueryString: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2078",
      messageParameters = Map(
        "jdbcTableName" -> jdbcTableName,
        "jdbcQueryString" -> jdbcQueryString))
  }

  def missingJdbcTableNameAndQueryError(
      jdbcTableName: String, jdbcQueryString: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2079",
      messageParameters = Map(
        "jdbcTableName" -> jdbcTableName,
        "jdbcQueryString" -> jdbcQueryString))
  }

  def emptyOptionError(optionName: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2080",
      messageParameters = Map("optionName" -> optionName))
  }

  def invalidJdbcTxnIsolationLevelError(
      jdbcTxnIsolationLevel: String, value: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2081",
      messageParameters = Map("value" -> value, "jdbcTxnIsolationLevel" -> jdbcTxnIsolationLevel))
  }

  def cannotGetJdbcTypeError(dt: DataType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2082",
      messageParameters = Map("catalogString" -> dt.catalogString))
  }

  def unrecognizedSqlTypeError(jdbcTypeId: String, typeName: String): Throwable = {
    new SparkSQLException(
      errorClass = "UNRECOGNIZED_SQL_TYPE",
      messageParameters = Map("typeName" -> typeName, "jdbcType" -> jdbcTypeId))
  }

  def unsupportedJdbcTypeError(content: String): SparkSQLException = {
    new SparkSQLException(
      errorClass = "_LEGACY_ERROR_TEMP_2083",
      messageParameters = Map("content" -> content))
  }

  def unsupportedArrayElementTypeBasedOnBinaryError(dt: DataType): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2084",
      messageParameters = Map("catalogString" -> dt.catalogString))
  }

  def nestedArraysUnsupportedError(): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2085",
      messageParameters = Map.empty)
  }

  def cannotTranslateNonNullValueForFieldError(pos: Int): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2086",
      messageParameters = Map("pos" -> pos.toString()))
  }

  def invalidJdbcNumPartitionsError(
      n: Int, jdbcNumPartitions: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2087",
      messageParameters = Map("n" -> n.toString(), "jdbcNumPartitions" -> jdbcNumPartitions))
  }

  def multiActionAlterError(tableName: String): Throwable = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "UNSUPPORTED_FEATURE.MULTI_ACTION_ALTER",
      messageParameters = Map("tableName" -> tableName))
  }

  def dataTypeUnsupportedYetError(dataType: DataType): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2088",
      messageParameters = Map("dataType" -> dataType.toString()))
  }

  def unsupportedOperationForDataTypeError(
      dataType: DataType): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2089",
      messageParameters = Map("catalogString" -> dataType.catalogString))
  }

  def inputFilterNotFullyConvertibleError(owner: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2090",
      messageParameters = Map("owner" -> owner),
      cause = null)
  }

  def cannotReadFooterForFileError(file: Path, e: Exception): Throwable = {
    new SparkException(
      errorClass = "CANNOT_READ_FILE_FOOTER",
      messageParameters = Map("file" -> file.toString()),
      cause = e)
  }

  def foundDuplicateFieldInCaseInsensitiveModeError(
      requiredFieldName: String, matchedOrcFields: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2093",
      messageParameters = Map(
        "requiredFieldName" -> requiredFieldName,
        "matchedOrcFields" -> matchedOrcFields))
  }

  def foundDuplicateFieldInFieldIdLookupModeError(
      requiredId: Int, matchedFields: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2094",
      messageParameters = Map(
        "requiredId" -> requiredId.toString(),
        "matchedFields" -> matchedFields))
  }

  def failedToMergeIncompatibleSchemasError(
      left: StructType, right: StructType, e: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2095",
      messageParameters = Map("left" -> left.toString(), "right" -> right.toString()),
      cause = e)
  }

  def ddlUnsupportedTemporarilyError(ddl: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2096",
      messageParameters = Map("ddl" -> ddl))
  }

  def executeBroadcastTimeoutError(timeout: Long, ex: Option[TimeoutException]): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2097",
      messageParameters = Map(
        "timeout" -> timeout.toString(),
        "broadcastTimeout" -> toSQLConf(SQLConf.BROADCAST_TIMEOUT.key),
        "autoBroadcastJoinThreshold" -> toSQLConf(SQLConf.AUTO_BROADCASTJOIN_THRESHOLD.key)),
      cause = ex.orNull)
  }

  def cannotCompareCostWithTargetCostError(cost: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2098",
      messageParameters = Map("cost" -> cost))
  }

  def notSupportTypeError(dataType: DataType): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2100",
      messageParameters = Map("dataType" -> dataType.toString()),
      cause = null)
  }

  def notSupportNonPrimitiveTypeError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2101",
      messageParameters = Map.empty)
  }

  def unsupportedTypeError(dataType: DataType): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2102",
      messageParameters = Map("catalogString" -> dataType.catalogString),
      cause = null)
  }

  def useDictionaryEncodingWhenDictionaryOverflowError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2103",
      messageParameters = Map.empty,
      cause = null)
  }

  def endOfIteratorError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2104",
      messageParameters = Map.empty,
      cause = null)
  }

  def cannotAllocateMemoryToGrowBytesToBytesMapError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2105",
      messageParameters = Map.empty,
      cause = null)
  }

  def cannotAcquireMemoryToBuildLongHashedRelationError(size: Long, got: Long): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2106",
      messageParameters = Map("size" -> size.toString(), "got" -> got.toString()),
      cause = null)
  }

  def cannotAcquireMemoryToBuildUnsafeHashedRelationError(): Throwable = {
    new SparkOutOfMemoryError(
      "_LEGACY_ERROR_TEMP_2107")
  }

  def rowLargerThan256MUnsupportedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2108",
      messageParameters = Map.empty)
  }

  def cannotBuildHashedRelationWithUniqueKeysExceededError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2109",
      messageParameters = Map.empty)
  }

  def cannotBuildHashedRelationLargerThan8GError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2110",
      messageParameters = Map.empty)
  }

  def failedToPushRowIntoRowQueueError(rowQueue: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2111",
      messageParameters = Map("rowQueue" -> rowQueue),
      cause = null)
  }

  def unexpectedWindowFunctionFrameError(frame: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2112",
      messageParameters = Map("frame" -> frame))
  }

  def cannotParseStatisticAsPercentileError(
      stats: String, e: NumberFormatException): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2113",
      messageParameters = Map("stats" -> stats),
      cause = e)
  }

  def statisticNotRecognizedError(stats: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2114",
      messageParameters = Map("stats" -> stats))
  }

  def unknownColumnError(unknownColumn: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2115",
      messageParameters = Map("unknownColumn" -> unknownColumn))
  }

  def unexpectedAccumulableUpdateValueError(o: Any): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "_LEGACY_ERROR_TEMP_2116",
      messageParameters = Map("o" -> o.toString()))
  }

  def unscaledValueTooLargeForPrecisionError(
      value: Decimal,
      decimalPrecision: Int,
      decimalScale: Int,
      context: SQLQueryContext = null): ArithmeticException = {
    DataTypeErrors.unscaledValueTooLargeForPrecisionError(
      value, decimalPrecision, decimalScale, context)
  }

  def decimalPrecisionExceedsMaxPrecisionError(
      precision: Int, maxPrecision: Int): SparkArithmeticException = {
    DataTypeErrors.decimalPrecisionExceedsMaxPrecisionError(precision, maxPrecision)
  }

  def outOfDecimalTypeRangeError(str: UTF8String): SparkArithmeticException = {
    new SparkArithmeticException(
      errorClass = "NUMERIC_OUT_OF_SUPPORTED_RANGE",
      messageParameters = Map(
        "value" -> str.toString),
      context = Array.empty,
      summary = "")
  }

  def unsupportedArrayTypeError(clazz: Class[_]): SparkRuntimeException = {
    DataTypeErrors.unsupportedJavaTypeError(clazz)
  }

  def unsupportedJavaTypeError(clazz: Class[_]): SparkRuntimeException = {
    DataTypeErrors.unsupportedJavaTypeError(clazz)
  }

  def failedParsingStructTypeError(raw: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "FAILED_PARSE_STRUCT_TYPE",
      messageParameters = Map("raw" -> toSQLValue(raw, StringType)))
  }

  def cannotMergeDecimalTypesWithIncompatibleScaleError(
      leftScale: Int, rightScale: Int): Throwable = {
    DataTypeErrors.cannotMergeDecimalTypesWithIncompatibleScaleError(leftScale, rightScale)
  }

  def cannotMergeIncompatibleDataTypesError(left: DataType, right: DataType): Throwable = {
    DataTypeErrors.cannotMergeIncompatibleDataTypesError(left, right)
  }

  def exceedMapSizeLimitError(size: Int): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2126",
      messageParameters = Map(
        "size" -> size.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def duplicateMapKeyFoundError(key: Any): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "DUPLICATED_MAP_KEY",
      messageParameters = Map(
        "key" -> key.toString(),
        "mapKeyDedupPolicy" -> toSQLConf(SQLConf.MAP_KEY_DEDUP_POLICY.key)))
  }

  def mapDataKeyArrayLengthDiffersFromValueArrayLengthError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2128",
      messageParameters = Map.empty)
  }

  def registeringStreamingQueryListenerError(e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2131",
      messageParameters = Map.empty,
      cause = e)
  }

  def concurrentQueryInstanceError(): Throwable = {
    new SparkConcurrentModificationException(
      errorClass = "CONCURRENT_QUERY",
      messageParameters = Map.empty[String, String])
  }

  def concurrentStreamLogUpdate(batchId: Long): Throwable = {
    new SparkException(
      errorClass = "CONCURRENT_STREAM_LOG_UPDATE",
      messageParameters = Map("batchId" -> batchId.toString),
      cause = null)
  }

  def cannotParseJsonArraysAsStructsError(recordStr: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "MALFORMED_RECORD_IN_PARSING.CANNOT_PARSE_JSON_ARRAYS_AS_STRUCTS",
      messageParameters = Map(
        "badRecord" -> recordStr,
        "failFastMode" -> FailFastMode.name))
  }

  def cannotParseStringAsDataTypeError(parser: JsonParser, token: JsonToken, dataType: DataType)
  : SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2133",
      messageParameters = Map(
        "fieldName" -> parser.getCurrentName,
        "fieldValue" -> parser.getText,
        "token" -> token.toString(),
        "dataType" -> dataType.toString()))
  }

  def emptyJsonFieldValueError(dataType: DataType): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "EMPTY_JSON_FIELD_VALUE",
      messageParameters = Map("dataType" -> toSQLType(dataType)))
  }

  def cannotParseJSONFieldError(parser: JsonParser, jsonType: JsonToken, dataType: DataType)
  : SparkRuntimeException = {
    cannotParseJSONFieldError(parser.getCurrentName, parser.getText, jsonType, dataType)
  }

  def cannotParseJSONFieldError(
      fieldName: String,
      fieldValue: String,
      jsonType: JsonToken,
      dataType: DataType): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "CANNOT_PARSE_JSON_FIELD",
      messageParameters = Map(
        "fieldName" -> toSQLValue(fieldName, StringType),
        "fieldValue" -> fieldValue,
        "jsonType" -> jsonType.toString(),
        "dataType" -> toSQLType(dataType)))
  }

  def rootConverterReturnNullError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_JSON_ROOT_FIELD",
      messageParameters = Map.empty)
  }

  def attributesForTypeUnsupportedError(schema: Schema): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2142",
      messageParameters = Map(
        "schema" -> schema.toString()))
  }

  def paramExceedOneCharError(paramName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2145",
      messageParameters = Map(
        "paramName" -> paramName))
  }

  def paramIsNotIntegerError(paramName: String, value: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2146",
      messageParameters = Map(
        "paramName" -> paramName,
        "value" -> value))
  }

  def paramIsNotBooleanValueError(paramName: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2147",
      messageParameters = Map(
        "paramName" -> paramName),
      cause = null)
  }

  def foundNullValueForNotNullableFieldError(name: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2148",
      messageParameters = Map(
        "name" -> name))
  }

  def malformedCSVRecordError(badRecord: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "MALFORMED_CSV_RECORD",
      messageParameters = Map("badRecord" -> badRecord))
  }

  def elementsOfTupleExceedLimitError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2150",
      messageParameters = Map.empty)
  }

  def expressionDecodingError(e: Exception, expressions: Seq[Expression]): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2151",
      messageParameters = Map(
        "e" -> e.toString(),
        "expressions" -> expressions.map(
          _.simpleString(SQLConf.get.maxToStringFields)).mkString("\n")),
      cause = e)
  }

  def expressionEncodingError(e: Exception, expressions: Seq[Expression]): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2152",
      messageParameters = Map(
        "e" -> e.toString(),
        "expressions" -> expressions.map(
          _.simpleString(SQLConf.get.maxToStringFields)).mkString("\n")),
      cause = e)
  }

  def classHasUnexpectedSerializerError(
      clsName: String, objSerializer: Expression): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2153",
      messageParameters = Map(
        "clsName" -> clsName,
        "objSerializer" -> objSerializer.toString()))
  }

  def unsupportedOperandTypeForSizeFunctionError(
      dataType: DataType): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2156",
      messageParameters = Map(
        "dataType" -> dataType.getClass.getCanonicalName))
  }

  def unexpectedValueForStartInFunctionError(prettyName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2157",
      messageParameters = Map(
        "prettyName" -> prettyName))
  }

  def unexpectedValueForLengthInFunctionError(prettyName: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2158",
      messageParameters = Map(
        "prettyName" -> prettyName))
  }

  def invalidIndexOfZeroError(context: SQLQueryContext): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_INDEX_OF_ZERO",
      cause = null,
      messageParameters = Map.empty,
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def concatArraysWithElementsExceedLimitError(numberOfElements: Long): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2159",
      messageParameters = Map(
        "numberOfElements" -> numberOfElements.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def flattenArraysWithElementsExceedLimitError(numberOfElements: Long): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2160",
      messageParameters = Map(
        "numberOfElements" -> numberOfElements.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def createArrayWithElementsExceedLimitError(count: Any): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2161",
      messageParameters = Map(
        "count" -> count.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def unionArrayWithElementsExceedLimitError(length: Int): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2162",
      messageParameters = Map(
        "length" -> length.toString(),
        "maxRoundedArrayLength" -> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString()))
  }

  def initialTypeNotTargetDataTypeError(
      dataType: DataType, target: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2163",
      messageParameters = Map(
        "dataType" -> dataType.catalogString,
        "target" -> target))
  }

  def initialTypeNotTargetDataTypesError(dataType: DataType): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2164",
      messageParameters = Map(
        "dataType" -> dataType.catalogString,
        "arrayType" -> ArrayType.simpleString,
        "structType" -> StructType.simpleString,
        "mapType" -> MapType.simpleString))
  }

  def malformedRecordsDetectedInSchemaInferenceError(e: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2165",
      messageParameters = Map(
        "failFastMode" -> FailFastMode.name),
      cause = e)
  }

  def malformedJSONError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2166",
      messageParameters = Map.empty,
      cause = null)
  }

  def malformedRecordsDetectedInSchemaInferenceError(dataType: DataType): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2167",
      messageParameters = Map(
        "failFastMode" -> FailFastMode.name,
        "dataType" -> dataType.catalogString),
      cause = null)
  }

  def decorrelateInnerQueryThroughPlanUnsupportedError(
      plan: LogicalPlan): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2168",
      messageParameters = Map(
        "plan" -> plan.nodeName))
  }

  def methodCalledInAnalyzerNotAllowedError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2169",
      messageParameters = Map.empty)
  }

  def cannotSafelyMergeSerdePropertiesError(
      props1: Map[String, String],
      props2: Map[String, String],
      conflictKeys: Set[String]): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2170",
      messageParameters = Map(
        "props1" -> props1.map { case (k, v) => s"$k=$v" }.mkString("{", ",", "}"),
        "props2" -> props2.map { case (k, v) => s"$k=$v" }.mkString("{", ",", "}"),
        "conflictKeys" -> conflictKeys.mkString(", ")))
  }

  def pairUnsupportedAtFunctionError(
      r1: ValueInterval,
      r2: ValueInterval,
      function: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2171",
      messageParameters = Map(
        "r1" -> r1.toString(),
        "r2" -> r2.toString(),
        "function" -> function))
  }

  def onceStrategyIdempotenceIsBrokenForBatchError[TreeType <: TreeNode[_]](
      batchName: String, plan: TreeType, reOptimized: TreeType): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2172",
      messageParameters = Map(
        "batchName" -> batchName,
        "plan" -> sideBySide(plan.treeString, reOptimized.treeString).mkString("\n")))
  }

  def ruleIdNotFoundForRuleError(ruleName: String): Throwable = {
    new SparkException(
      errorClass = "RULE_ID_NOT_FOUND",
      messageParameters = Map("ruleName" -> ruleName),
      cause = null)
  }

  def cannotCreateArrayWithElementsExceedLimitError(
      numElements: Long, additionalErrorMessage: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2176",
      messageParameters = Map(
        "numElements" -> numElements.toString(),
        "maxRoundedArrayLength"-> ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH.toString(),
        "additionalErrorMessage" -> additionalErrorMessage))
  }

  def malformedRecordsDetectedInRecordParsingError(
      badRecord: String, e: BadRecordException): Throwable = {
    new SparkException(
      errorClass = "MALFORMED_RECORD_IN_PARSING.WITHOUT_SUGGESTION",
      messageParameters = Map(
        "badRecord" -> badRecord,
        "failFastMode" -> FailFastMode.name),
      cause = e)
  }

  def remoteOperationsUnsupportedError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2178",
      messageParameters = Map.empty)
  }

  def invalidKerberosConfigForHiveServer2Error(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2179",
      messageParameters = Map.empty,
      cause = null)
  }

  def parentSparkUIToAttachTabNotFoundError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2180",
      messageParameters = Map.empty,
      cause = null)
  }

  def inferSchemaUnsupportedForHiveError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2181",
      messageParameters = Map.empty)
  }

  def requestedPartitionsMismatchTablePartitionsError(
      table: CatalogTable, partition: Map[String, Option[String]]): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2182",
      messageParameters = Map(
        "tableIdentifier" -> table.identifier.table,
        "partitionKeys" -> partition.keys.mkString(","),
        "partitionColumnNames" -> table.partitionColumnNames.mkString(",")),
      cause = null)
  }

  def dynamicPartitionKeyNotAmongWrittenPartitionPathsError(key: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2183",
      messageParameters = Map(
        "key" -> toSQLValue(key, StringType)),
      cause = null)
  }

  def cannotRemovePartitionDirError(partitionPath: Path): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2184",
      messageParameters = Map(
        "partitionPath" -> partitionPath.toString()))
  }

  def cannotCreateStagingDirError(message: String, e: IOException): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2185",
      messageParameters = Map(
        "message" -> message),
      cause = e)
  }

  def serDeInterfaceNotFoundError(e: NoClassDefFoundError): SparkClassNotFoundException = {
    new SparkClassNotFoundException(
      errorClass = "_LEGACY_ERROR_TEMP_2186",
      messageParameters = Map.empty,
      cause = e)
  }

  def convertHiveTableToCatalogTableError(
      e: SparkException, dbName: String, tableName: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2187",
      messageParameters = Map(
        "message" -> e.getMessage,
        "dbName" -> dbName,
        "tableName" -> tableName),
      cause = e)
  }

  def cannotRecognizeHiveTypeError(
      e: ParseException, fieldType: String, fieldName: String): Throwable = {
    new SparkException(
      errorClass = "CANNOT_RECOGNIZE_HIVE_TYPE",
      messageParameters = Map(
        "fieldType" -> toSQLType(fieldType),
        "fieldName" -> toSQLId(fieldName)),
      cause = e)
  }

  def getTablesByTypeUnsupportedByHiveVersionError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2189",
      messageParameters = Map.empty)
  }

  def dropTableWithPurgeUnsupportedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2190",
      messageParameters = Map.empty)
  }

  def alterTableWithDropPartitionAndPurgeUnsupportedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2191",
      messageParameters = Map.empty)
  }

  def invalidPartitionFilterError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2192",
      messageParameters = Map.empty)
  }

  def getPartitionMetadataByFilterError(e: InvocationTargetException): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2193",
      messageParameters = Map(
        "hiveMetastorePartitionPruningFallbackOnException" ->
          SQLConf.HIVE_METASTORE_PARTITION_PRUNING_FALLBACK_ON_EXCEPTION.key),
      cause = e)
  }

  def unsupportedHiveMetastoreVersionError(
      version: String, key: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2194",
      messageParameters = Map(
        "version" -> version,
        "key" -> key))
  }

  def loadHiveClientCausesNoClassDefFoundError(
      cnf: NoClassDefFoundError,
      execJars: Seq[URL],
      key: String,
      e: InvocationTargetException): SparkClassNotFoundException = {
    new SparkClassNotFoundException(
      errorClass = "_LEGACY_ERROR_TEMP_2195",
      messageParameters = Map(
        "cnf" -> cnf.toString(),
        "execJars" -> execJars.mkString(", "),
        "key" -> key),
      cause = e)
  }

  def cannotFetchTablesOfDatabaseError(dbName: String, e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2196",
      messageParameters = Map(
        "dbName" -> dbName),
      cause = e)
  }

  def illegalLocationClauseForViewPartitionError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2197",
      messageParameters = Map.empty,
      cause = null)
  }

  def renamePathAsExistsPathError(srcPath: Path, dstPath: Path): Throwable = {
    new SparkFileAlreadyExistsException(
      errorClass = "FAILED_RENAME_PATH",
      messageParameters = Map(
        "sourcePath" -> srcPath.toString,
        "targetPath" -> dstPath.toString))
  }

  def renameAsExistsPathError(dstPath: Path): SparkFileAlreadyExistsException = {
    new SparkFileAlreadyExistsException(
      errorClass = "_LEGACY_ERROR_TEMP_2198",
      messageParameters = Map(
        "dstPath" -> dstPath.toString()))
  }

  def renameSrcPathNotFoundError(srcPath: Path): Throwable = {
    new SparkFileNotFoundException(
      errorClass = "RENAME_SRC_PATH_NOT_FOUND",
      messageParameters = Map("sourcePath" -> srcPath.toString))
  }

  def failedRenameTempFileError(srcPath: Path, dstPath: Path): Throwable = {
    new SparkException(
      errorClass = "FAILED_RENAME_TEMP_FILE",
      messageParameters = Map(
        "srcPath" -> srcPath.toString(),
        "dstPath" -> dstPath.toString()),
      cause = null)
  }

  def legacyMetadataPathExistsError(metadataPath: Path, legacyMetadataPath: Path): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2200",
      messageParameters = Map(
        "metadataPath" -> metadataPath.toString(),
        "legacyMetadataPath" -> legacyMetadataPath.toString(),
        "StreamingCheckpointEscaptedPathCheckEnabled" ->
          SQLConf.STREAMING_CHECKPOINT_ESCAPED_PATH_CHECK_ENABLED.key),
      cause = null)
  }

  def partitionColumnNotFoundInSchemaError(
      col: String, schema: StructType): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2201",
      messageParameters = Map(
        "col" -> col,
        "schema" -> schema.toString()))
  }

  def stateNotDefinedOrAlreadyRemovedError(): Throwable = {
      new NoSuchElementException("State is either not defined or has already been removed")
  }

  def cannotSetTimeoutDurationError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2203",
      messageParameters = Map.empty)
  }

  def cannotGetEventTimeWatermarkError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2204",
      messageParameters = Map.empty)
  }

  def cannotSetTimeoutTimestampError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2205",
      messageParameters = Map.empty)
  }

  def batchMetadataFileNotFoundError(batchMetadataFile: Path): SparkFileNotFoundException = {
    new SparkFileNotFoundException(
      errorClass = "BATCH_METADATA_NOT_FOUND",
      messageParameters = Map(
        "batchMetadataFile" -> batchMetadataFile.toString()))
  }

  def multiStreamingQueriesUsingPathConcurrentlyError(
      path: String, e: FileAlreadyExistsException): SparkConcurrentModificationException = {
    new SparkConcurrentModificationException(
      errorClass = "_LEGACY_ERROR_TEMP_2207",
      messageParameters = Map(
        "path" -> path),
      cause = e)
  }

  def addFilesWithAbsolutePathUnsupportedError(
      commitProtocol: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2208",
      messageParameters = Map(
        "commitProtocol" -> commitProtocol))
  }

  def microBatchUnsupportedByDataSourceError(
      srcName: String,
      disabledSources: String,
      table: Table): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2209",
      messageParameters = Map(
        "srcName" -> srcName,
        "disabledSources" -> disabledSources,
        "table" -> table.toString()))
  }

  def cannotExecuteStreamingRelationExecError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2210",
      messageParameters = Map.empty)
  }

  def invalidStreamingOutputModeError(
      outputMode: Option[OutputMode]): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2211",
      messageParameters = Map(
        "outputMode" -> outputMode.toString()))
  }

  def invalidCatalogNameError(name: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2212",
      messageParameters = Map(
        "name" -> name),
      cause = null)
  }

  def catalogPluginClassNotFoundError(name: String): Throwable = {
    new CatalogNotFoundException(
      s"Catalog '$name' plugin class not found: spark.sql.catalog.$name is not defined")
  }

  def catalogPluginClassNotImplementedError(name: String, pluginClassName: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2214",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = null)
  }

  def catalogPluginClassNotFoundForCatalogError(
      name: String,
      pluginClassName: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2215",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = e)
  }

  def catalogFailToFindPublicNoArgConstructorError(
      name: String,
      pluginClassName: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2216",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = e)
  }

  def catalogFailToCallPublicNoArgConstructorError(
      name: String,
      pluginClassName: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2217",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = e)
  }

  def cannotInstantiateAbstractCatalogPluginClassError(
      name: String,
      pluginClassName: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2218",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = e.getCause)
  }

  def failedToInstantiateConstructorForCatalogError(
      name: String,
      pluginClassName: String,
      e: Exception): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2219",
      messageParameters = Map(
        "name" -> name,
        "pluginClassName" -> pluginClassName),
      cause = e.getCause)
  }

  def noSuchElementExceptionError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2220",
      messageParameters = Map.empty,
      cause = null)
  }

  def sqlConfigNotFoundError(key: String): SparkNoSuchElementException = {
    new SparkNoSuchElementException(
      errorClass = "SQL_CONF_NOT_FOUND",
      messageParameters = Map("sqlConf" -> toSQLConf(key)))
  }

  def cannotMutateReadOnlySQLConfError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2222",
      messageParameters = Map.empty)
  }

  def cannotCloneOrCopyReadOnlySQLConfError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2223",
      messageParameters = Map.empty)
  }

  def cannotGetSQLConfInSchedulerEventLoopThreadError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2224",
      messageParameters = Map.empty,
      cause = null)
  }

  def unsupportedOperationExceptionError(): SparkUnsupportedOperationException = {
    DataTypeErrors.unsupportedOperationExceptionError()
  }

  def nullLiteralsCannotBeCastedError(name: String): SparkUnsupportedOperationException = {
    DataTypeErrors.nullLiteralsCannotBeCastedError(name)
  }

  def notUserDefinedTypeError(name: String, userClass: String): Throwable = {
    DataTypeErrors.notUserDefinedTypeError(name, userClass)
  }

  def cannotLoadUserDefinedTypeError(name: String, userClass: String): Throwable = {
    DataTypeErrors.cannotLoadUserDefinedTypeError(name, userClass)
  }

  def notPublicClassError(name: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2229",
      messageParameters = Map(
        "name" -> name))
  }

  def primitiveTypesNotSupportedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2230",
      messageParameters = Map.empty)
  }

  def fieldIndexOnRowWithoutSchemaError(): SparkUnsupportedOperationException = {
    DataTypeErrors.fieldIndexOnRowWithoutSchemaError()
  }

  def valueIsNullError(index: Int): Throwable = {
    DataTypeErrors.valueIsNullError(index)
  }

  def onlySupportDataSourcesProvidingFileFormatError(providingClass: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2233",
      messageParameters = Map(
        "providingClass" -> providingClass),
      cause = null)
  }

  def cannotRestorePermissionsForPathError(permission: FsPermission, path: Path): Throwable = {
    new SparkSecurityException(
      errorClass = "CANNOT_RESTORE_PERMISSIONS_FOR_PATH",
      messageParameters = Map(
        "permission" -> permission.toString,
        "path" -> path.toString))
  }

  def failToSetOriginalACLBackError(
      aclEntries: String, path: Path, e: Throwable): SparkSecurityException = {
    new SparkSecurityException(
      errorClass = "_LEGACY_ERROR_TEMP_2234",
      messageParameters = Map(
        "aclEntries" -> aclEntries,
        "path" -> path.toString(),
        "message" -> e.getMessage))
  }

  def multiFailuresInStageMaterializationError(error: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2235",
      messageParameters = Map.empty,
      cause = error)
  }

  def unrecognizedCompressionSchemaTypeIDError(typeId: Int): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2236",
      messageParameters = Map(
        "typeId" -> typeId.toString()))
  }

  def getParentLoggerNotImplementedError(
      className: String): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "_LEGACY_ERROR_TEMP_2237",
      messageParameters = Map(
        "className" -> className))
  }

  def cannotCreateParquetConverterForTypeError(
      t: DecimalType, parquetType: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2238",
      messageParameters = Map(
        "typeName" -> t.typeName,
        "parquetType" -> parquetType))
  }

  def cannotCreateParquetConverterForDecimalTypeError(
      t: DecimalType, parquetType: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2239",
      messageParameters = Map(
        "t" -> t.json,
        "parquetType" -> parquetType))
  }

  def cannotCreateParquetConverterForDataTypeError(
      t: DataType, parquetType: String): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "_LEGACY_ERROR_TEMP_2240",
      messageParameters = Map(
        "t" -> t.json,
        "parquetType" -> parquetType))
  }

  def cannotAddMultiPartitionsOnNonatomicPartitionTableError(
      tableName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2241",
      messageParameters = Map(
        "tableName" -> tableName))
  }

  def userSpecifiedSchemaUnsupportedByDataSourceError(
      provider: TableProvider): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2242",
      messageParameters = Map(
        "provider" -> provider.getClass.getSimpleName))
  }

  def cannotDropMultiPartitionsOnNonatomicPartitionTableError(
      tableName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2243",
      messageParameters = Map(
        "tableName" -> tableName))
  }

  def truncateMultiPartitionUnsupportedError(
      tableName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2244",
      messageParameters = Map(
        "tableName" -> tableName))
  }

  def overwriteTableByUnsupportedExpressionError(table: Table): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2245",
      messageParameters = Map(
        "table" -> table.toString()),
      cause = null)
  }

  def dynamicPartitionOverwriteUnsupportedByTableError(table: Table): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2246",
      messageParameters = Map(
        "table" -> table.toString()),
      cause = null)
  }

  def failedMergingSchemaError(
      leftSchema: StructType,
      rightSchema: StructType,
      e: SparkException): Throwable = {
    new SparkException(
      errorClass = "CANNOT_MERGE_SCHEMAS",
      messageParameters = Map("left" -> toSQLType(leftSchema), "right" -> toSQLType(rightSchema)),
      cause = e)
  }

  def cannotBroadcastTableOverMaxTableRowsError(
      maxBroadcastTableRows: Long, numRows: Long): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2248",
      messageParameters = Map(
        "maxBroadcastTableRows" -> maxBroadcastTableRows.toString(),
        "numRows" -> numRows.toString()),
      cause = null)
  }

  def cannotBroadcastTableOverMaxTableBytesError(
      maxBroadcastTableBytes: Long, dataSize: Long): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2249",
      messageParameters = Map(
        "maxBroadcastTableBytes" -> Utils.bytesToString(maxBroadcastTableBytes),
        "dataSize" -> Utils.bytesToString(dataSize)),
      cause = null)
  }

  def notEnoughMemoryToBuildAndBroadcastTableError(
      oe: OutOfMemoryError, tables: Seq[TableIdentifier]): Throwable = {
    val analyzeTblMsg = if (tables.nonEmpty) {
      " or analyze these tables through: " +
        s"${tables.map(t => s"ANALYZE TABLE $t COMPUTE STATISTICS;").mkString(" ")}."
    } else {
      "."
    }
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2250",
      messageParameters = Map(
        "autoBroadcastjoinThreshold" -> SQLConf.AUTO_BROADCASTJOIN_THRESHOLD.key,
        "driverMemory" -> SparkLauncher.DRIVER_MEMORY,
        "analyzeTblMsg" -> analyzeTblMsg),
      cause = oe.getCause)
  }

  def executeCodePathUnsupportedError(execName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2251",
      messageParameters = Map(
        "execName" -> execName))
  }

  def cannotMergeClassWithOtherClassError(
      className: String, otherClass: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2252",
      messageParameters = Map(
        "className" -> className,
        "otherClass" -> otherClass))
  }

  def continuousProcessingUnsupportedByDataSourceError(
      sourceName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2253",
      messageParameters = Map(
        "sourceName" -> sourceName))
  }

  def failedToReadDataError(failureReason: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2254",
      messageParameters = Map.empty,
      cause = failureReason)
  }

  def failedToGenerateEpochMarkerError(failureReason: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2255",
      messageParameters = Map.empty,
      cause = failureReason)
  }

  def foreachWriterAbortedDueToTaskFailureError(): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2256",
      messageParameters = Map.empty,
      cause = null)
  }

  def incorrectRampUpRate(rowsPerSecond: Long,
      maxSeconds: Long,
      rampUpTimeSeconds: Long): Throwable = {
    new SparkRuntimeException(
      errorClass = "INCORRECT_RAMP_UP_RATE",
      messageParameters = Map(
        "rowsPerSecond" -> rowsPerSecond.toString,
        "maxSeconds" -> maxSeconds.toString,
        "rampUpTimeSeconds" -> rampUpTimeSeconds.toString
      ))
  }

  def incorrectEndOffset(rowsPerSecond: Long,
      maxSeconds: Long,
      endSeconds: Long): Throwable = {
    SparkException.internalError(
      s"Max offset with ${rowsPerSecond.toString} rowsPerSecond is ${maxSeconds.toString}, " +
        s"but it's ${endSeconds.toString} now.")
  }

  def failedToReadDeltaFileError(fileToRead: Path, clazz: String, keySize: Int): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2258",
      messageParameters = Map(
        "fileToRead" -> fileToRead.toString(),
        "clazz" -> clazz,
        "keySize" -> keySize.toString()),
      cause = null)
  }

  def failedToReadSnapshotFileError(fileToRead: Path, clazz: String, message: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2259",
      messageParameters = Map(
        "fileToRead" -> fileToRead.toString(),
        "clazz" -> clazz,
        "message" -> message),
      cause = null)
  }

  def cannotPurgeAsBreakInternalStateError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2260",
      messageParameters = Map.empty)
  }

  def cleanUpSourceFilesUnsupportedError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2261",
      messageParameters = Map.empty)
  }

  def latestOffsetNotCalledError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2262",
      messageParameters = Map.empty)
  }

  def legacyCheckpointDirectoryExistsError(
      checkpointPath: Path, legacyCheckpointDir: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2263",
      messageParameters = Map(
        "checkpointPath" -> checkpointPath.toString(),
        "legacyCheckpointDir" -> legacyCheckpointDir,
        "StreamingCheckpointEscapedPathCheckEnabled"
          -> SQLConf.STREAMING_CHECKPOINT_ESCAPED_PATH_CHECK_ENABLED.key),
      cause = null)
  }

  def subprocessExitedError(
      exitCode: Int, stderrBuffer: CircularBuffer, cause: Throwable): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2264",
      messageParameters = Map(
        "exitCode" -> exitCode.toString(),
        "stderrBuffer" -> stderrBuffer.toString()),
      cause = cause)
  }

  def outputDataTypeUnsupportedByNodeWithoutSerdeError(
      nodeName: String, dt: DataType): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2265",
      messageParameters = Map(
        "nodeName" -> nodeName,
        "dt" -> dt.getClass.getSimpleName),
      cause = null)
  }

  def invalidStartIndexError(numRows: Int, startIndex: Int): SparkArrayIndexOutOfBoundsException = {
    new SparkArrayIndexOutOfBoundsException(
      errorClass = "_LEGACY_ERROR_TEMP_2266",
      messageParameters = Map(
        "numRows" -> numRows.toString(),
        "startIndex" -> startIndex.toString()),
      context = Array.empty,
      summary = "")
  }

  def concurrentModificationOnExternalAppendOnlyUnsafeRowArrayError(
      className: String): SparkConcurrentModificationException = {
    new SparkConcurrentModificationException(
      errorClass = "_LEGACY_ERROR_TEMP_2267",
      messageParameters = Map(
        "className" -> className))
  }

  def doExecuteBroadcastNotImplementedError(
      nodeName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "_LEGACY_ERROR_TEMP_2268",
      messageParameters = Map(
        "nodeName" -> nodeName))
  }

  def defaultDatabaseNotExistsError(defaultDatabase: String): Throwable = {
    new SparkException(
      errorClass = "DEFAULT_DATABASE_NOT_EXISTS",
      messageParameters = Map("defaultDatabase" -> defaultDatabase),
      cause = null
    )
  }

  def databaseNameConflictWithSystemPreservedDatabaseError(globalTempDB: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2269",
      messageParameters = Map(
        "globalTempDB" -> globalTempDB,
        "globalTempDatabase" -> GLOBAL_TEMP_DATABASE.key),
      cause = null)
  }

  def commentOnTableUnsupportedError(): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "_LEGACY_ERROR_TEMP_2270",
      messageParameters = Map.empty)
  }

  def unsupportedUpdateColumnNullabilityError(): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "_LEGACY_ERROR_TEMP_2271",
      messageParameters = Map.empty)
  }

  def renameColumnUnsupportedForOlderMySQLError(): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "_LEGACY_ERROR_TEMP_2272",
      messageParameters = Map.empty)
  }

  def failedToExecuteQueryError(e: Throwable): SparkException = {
    val message = "Hit an error when executing a query" +
      (if (e.getMessage == null) "" else s": ${e.getMessage}")
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2273",
      messageParameters = Map(
        "message" -> message),
      cause = e)
  }

  def nestedFieldUnsupportedError(colName: String): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.REPLACE_NESTED_COLUMN",
      messageParameters = Map("colName" -> toSQLId(colName)))
  }

  def transformationsAndActionsNotInvokedByDriverError(): Throwable = {
    new SparkException(
      errorClass = "CANNOT_INVOKE_IN_TRANSFORMATIONS",
      messageParameters = Map.empty,
      cause = null)
  }

  def repeatedPivotsUnsupportedError(clause: String, operation: String): Throwable = {
    new SparkUnsupportedOperationException(
      errorClass = "REPEATED_CLAUSE",
      messageParameters = Map("clause" -> clause, "operation" -> operation))
  }

  def pivotNotAfterGroupByUnsupportedError(): Throwable = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.PIVOT_AFTER_GROUP_BY",
      messageParameters = Map.empty[String, String])
  }

  private val aesFuncName = toSQLId("aes_encrypt") + "/" + toSQLId("aes_decrypt")

  def invalidAesKeyLengthError(actualLength: Int): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_PARAMETER_VALUE.AES_KEY_LENGTH",
      messageParameters = Map(
        "parameter" -> toSQLId("key"),
        "functionName" -> aesFuncName,
        "actualLength" -> actualLength.toString()))
  }

  def aesModeUnsupportedError(mode: String, padding: String): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "UNSUPPORTED_FEATURE.AES_MODE",
      messageParameters = Map(
        "mode" -> mode,
        "padding" -> padding,
        "functionName" -> aesFuncName))
  }

  def aesCryptoError(detailMessage: String): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_PARAMETER_VALUE.AES_CRYPTO_ERROR",
      messageParameters = Map(
        "parameter" -> (toSQLId("expr") + ", " + toSQLId("key")),
        "functionName" -> aesFuncName,
        "detailMessage" -> detailMessage))
  }

  def invalidAesIvLengthError(mode: String, actualLength: Int): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_PARAMETER_VALUE.AES_IV_LENGTH",
      messageParameters = Map(
        "mode" -> mode,
        "parameter" -> toSQLId("iv"),
        "functionName" -> aesFuncName,
        "actualLength" -> actualLength.toString()))
  }

  def aesUnsupportedIv(mode: String): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "UNSUPPORTED_FEATURE.AES_MODE_IV",
      messageParameters = Map(
        "mode" -> mode,
        "functionName" -> toSQLId("aes_encrypt")))
  }

  def aesUnsupportedAad(mode: String): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "UNSUPPORTED_FEATURE.AES_MODE_AAD",
      messageParameters = Map(
        "mode" -> mode,
        "functionName" -> toSQLId("aes_encrypt")))
  }

  def hiveTableWithAnsiIntervalsError(
      table: TableIdentifier): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.HIVE_WITH_ANSI_INTERVALS",
      messageParameters = Map("tableName" -> toSQLId(table.nameParts)))
  }

  def cannotConvertOrcTimestampToTimestampNTZError(): Throwable = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.ORC_TYPE_CAST",
      messageParameters = Map(
        "orcType" -> toSQLType(TimestampType),
        "toType" -> toSQLType(TimestampNTZType)))
  }

  def cannotConvertOrcTimestampNTZToTimestampLTZError(): Throwable = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.ORC_TYPE_CAST",
      messageParameters = Map(
        "orcType" -> toSQLType(TimestampNTZType),
        "toType" -> toSQLType(TimestampType)))
  }

  def writePartitionExceedConfigSizeWhenDynamicPartitionError(
      numWrittenParts: Int,
      maxDynamicPartitions: Int,
      maxDynamicPartitionsKey: String): Throwable = {
    new SparkException(
      errorClass = "_LEGACY_ERROR_TEMP_2277",
      messageParameters = Map(
        "numWrittenParts" -> numWrittenParts.toString(),
        "maxDynamicPartitionsKey" -> maxDynamicPartitionsKey,
        "maxDynamicPartitions" -> maxDynamicPartitions.toString(),
        "numWrittenParts" -> numWrittenParts.toString()),
      cause = null)
  }

  def invalidNumberFormatError(
      dataType: DataType, input: String, format: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "INVALID_FORMAT.MISMATCH_INPUT",
      messageParameters = Map(
        "inputType" -> toSQLType(dataType),
        "input" -> input,
        "format" -> format))
  }

  def unsupportedMultipleBucketTransformsError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.MULTIPLE_BUCKET_TRANSFORMS",
      messageParameters = Map.empty)
  }

  def unsupportedCommentNamespaceError(
      namespace: String): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "UNSUPPORTED_FEATURE.COMMENT_NAMESPACE",
      messageParameters = Map("namespace" -> toSQLId(namespace)))
  }

  def unsupportedRemoveNamespaceCommentError(
      namespace: String): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "UNSUPPORTED_FEATURE.REMOVE_NAMESPACE_COMMENT",
      messageParameters = Map("namespace" -> toSQLId(namespace)))
  }

  def unsupportedDropNamespaceError(
      namespace: String): SparkSQLFeatureNotSupportedException = {
    new SparkSQLFeatureNotSupportedException(
      errorClass = "UNSUPPORTED_FEATURE.DROP_NAMESPACE",
      messageParameters = Map("namespace" -> toSQLId(namespace)))
  }

  def exceedMaxLimit(limit: Int): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "EXCEED_LIMIT_LENGTH",
      messageParameters = Map("limit" -> limit.toString)
    )
  }

  def timestampAddOverflowError(micros: Long, amount: Int, unit: String): ArithmeticException = {
    new SparkArithmeticException(
      errorClass = "DATETIME_OVERFLOW",
      messageParameters = Map(
        "operation" -> (s"add ${toSQLValue(amount, IntegerType)} $unit to " +
          s"${toSQLValue(DateTimeUtils.microsToInstant(micros), TimestampType)}")),
      context = Array.empty,
      summary = "")
  }

  def invalidBucketFile(path: String): Throwable = {
    new SparkException(
      errorClass = "INVALID_BUCKET_FILE",
      messageParameters = Map("path" -> path),
      cause = null)
  }

  def multipleRowSubqueryError(context: SQLQueryContext): Throwable = {
    new SparkException(
      errorClass = "SCALAR_SUBQUERY_TOO_MANY_ROWS",
      messageParameters = Map.empty,
      cause = null,
      context = getQueryContext(context),
      summary = getSummary(context))
  }

  def comparatorReturnsNull(firstValue: String, secondValue: String): Throwable = {
    new SparkException(
      errorClass = "COMPARATOR_RETURNS_NULL",
      messageParameters = Map("firstValue" -> firstValue, "secondValue" -> secondValue),
      cause = null)
  }

  def invalidPatternError(
      funcName: String,
      pattern: String,
      cause: Throwable): RuntimeException = {
    new SparkRuntimeException(
      errorClass = "INVALID_PARAMETER_VALUE.PATTERN",
      messageParameters = Map(
        "parameter" -> toSQLId("regexp"),
        "functionName" -> toSQLId(funcName),
        "value" -> toSQLValue(pattern, StringType)),
      cause = cause)
  }

  def tooManyArrayElementsError(
      numElements: Int,
      elementSize: Int): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "TOO_MANY_ARRAY_ELEMENTS",
      messageParameters = Map(
        "numElements" -> numElements.toString,
        "size" -> elementSize.toString))
  }

  def invalidEmptyLocationError(location: String): SparkIllegalArgumentException = {
    new SparkIllegalArgumentException(
      errorClass = "INVALID_EMPTY_LOCATION",
      messageParameters = Map("location" -> location))
  }

  def malformedProtobufMessageDetectedInMessageParsingError(e: Throwable): Throwable = {
    new SparkException(
      errorClass = "MALFORMED_PROTOBUF_MESSAGE",
      messageParameters = Map(
        "failFastMode" -> FailFastMode.name),
      cause = e)
  }

  def locationAlreadyExists(tableId: TableIdentifier, location: Path): Throwable = {
    new SparkRuntimeException(
      errorClass = "LOCATION_ALREADY_EXISTS",
      messageParameters = Map(
        "location" -> toSQLValue(location.toString, StringType),
        "identifier" -> toSQLId(tableId.nameParts)))
  }

  def cannotConvertCatalystValueToProtobufEnumTypeError(
      sqlColumn: Seq[String],
      protobufColumn: String,
      data: String,
      enumString: String): Throwable = {
    new AnalysisException(
      errorClass = "CANNOT_CONVERT_SQL_VALUE_TO_PROTOBUF_ENUM_TYPE",
      messageParameters = Map(
        "sqlColumn" -> toSQLId(sqlColumn),
        "protobufColumn" -> protobufColumn,
        "data" -> data,
        "enumString" -> enumString))
  }

  def hllInvalidLgK(function: String, min: Int, max: Int, value: String): Throwable = {
    new SparkRuntimeException(
      errorClass = "HLL_INVALID_LG_K",
      messageParameters = Map(
        "function" -> toSQLId(function),
        "min" -> toSQLValue(min, IntegerType),
        "max" -> toSQLValue(max, IntegerType),
        "value" -> value))
  }

  def hllInvalidInputSketchBuffer(function: String): Throwable = {
    new SparkRuntimeException(
      errorClass = "HLL_INVALID_INPUT_SKETCH_BUFFER",
      messageParameters = Map(
        "function" -> toSQLId(function)))
  }

  def hllUnionDifferentLgK(left: Int, right: Int, function: String): Throwable = {
    new SparkRuntimeException(
      errorClass = "HLL_UNION_DIFFERENT_LG_K",
      messageParameters = Map(
        "left" -> toSQLValue(left, IntegerType),
        "right" -> toSQLValue(right, IntegerType),
        "function" -> toSQLId(function)))
  }

  def mergeCardinalityViolationError(): SparkRuntimeException = {
    new SparkRuntimeException(
      errorClass = "MERGE_CARDINALITY_VIOLATION",
      messageParameters = Map.empty)
  }

  def unsupportedPurgePartitionError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.PURGE_PARTITION",
      messageParameters = Map.empty)
  }

  def unsupportedPurgeTableError(): SparkUnsupportedOperationException = {
    new SparkUnsupportedOperationException(
      errorClass = "UNSUPPORTED_FEATURE.PURGE_TABLE",
      messageParameters = Map.empty)
  }
}
