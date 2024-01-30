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

package org.apache.spark.sql.avro

import java.util.Locale

import scala.collection.JavaConverters._
import scala.collection.mutable

import org.apache.avro.{LogicalTypes, Schema, SchemaBuilder}
import org.apache.avro.LogicalTypes.{Date, Decimal, LocalTimestampMicros, LocalTimestampMillis, TimestampMicros, TimestampMillis}
import org.apache.avro.Schema.Type._

import org.apache.spark.annotation.DeveloperApi
import org.apache.spark.sql.catalyst.parser.CatalystSqlParser
import org.apache.spark.sql.types._
import org.apache.spark.sql.types.Decimal.minBytesForPrecision

/**
 * This object contains method that are used to convert sparkSQL schemas to avro schemas and vice
 * versa.
 */
@DeveloperApi
object SchemaConverters {
  private lazy val nullSchema = Schema.create(Schema.Type.NULL)

  /**
   * Internal wrapper for SQL data type and nullability.
   *
   * @since 2.4.0
   */
  case class SchemaType(dataType: DataType, nullable: Boolean)

  /**
   * Converts an Avro schema to a corresponding Spark SQL schema.
   *
   * @since 2.4.0
   */
  def toSqlType(avroSchema: Schema): SchemaType = {
    toSqlTypeHelper(avroSchema, Set.empty, AvroOptions(Map()))
  }
  def toSqlType(avroSchema: Schema, options: Map[String, String]): SchemaType = {
    toSqlTypeHelper(avroSchema, Set.empty, AvroOptions(options))
  }

  // The property specifies Catalyst type of the given field
  private val CATALYST_TYPE_PROP_NAME = "spark.sql.catalyst.type"

  private def toSqlTypeHelper(
      avroSchema: Schema,
      existingRecordNames: Set[String],
      avroOptions: AvroOptions): SchemaType = {
    avroSchema.getType match {
      case INT => avroSchema.getLogicalType match {
        case _: Date => SchemaType(DateType, nullable = false)
        case _ =>
          val catalystTypeAttrValue = avroSchema.getProp(CATALYST_TYPE_PROP_NAME)
          val catalystType = if (catalystTypeAttrValue == null) {
            IntegerType
          } else {
            CatalystSqlParser.parseDataType(catalystTypeAttrValue)
          }
          SchemaType(catalystType, nullable = false)
      }
      case STRING => SchemaType(StringType, nullable = false)
      case BOOLEAN => SchemaType(BooleanType, nullable = false)
      case BYTES | FIXED => avroSchema.getLogicalType match {
        // For FIXED type, if the precision requires more bytes than fixed size, the logical
        // type will be null, which is handled by Avro library.
        case d: Decimal => SchemaType(DecimalType(d.getPrecision, d.getScale), nullable = false)
        case _ => SchemaType(BinaryType, nullable = false)
      }

      case DOUBLE => SchemaType(DoubleType, nullable = false)
      case FLOAT => SchemaType(FloatType, nullable = false)
      case LONG => avroSchema.getLogicalType match {
        case d: CustomDecimal =>
          SchemaType(DecimalType(d.precision, d.scale), nullable = false)
        case _: TimestampMillis | _: TimestampMicros => SchemaType(TimestampType, nullable = false)
        case _: LocalTimestampMillis | _: LocalTimestampMicros =>
          SchemaType(TimestampNTZType, nullable = false)
        case _ =>
          val catalystTypeAttrValue = avroSchema.getProp(CATALYST_TYPE_PROP_NAME)
          val catalystType = if (catalystTypeAttrValue == null) {
            LongType
          } else {
            CatalystSqlParser.parseDataType(catalystTypeAttrValue)
          }
          SchemaType(catalystType, nullable = false)
      }

      case ENUM => SchemaType(StringType, nullable = false)

      case NULL => SchemaType(NullType, nullable = true)

      case RECORD =>
        if (existingRecordNames.contains(avroSchema.getFullName)) {
          throw new IncompatibleSchemaException(s"""
            |Found recursive reference in Avro schema, which can not be processed by Spark:
            |${avroSchema.toString(true)}
          """.stripMargin)
        }
        val newRecordNames = existingRecordNames + avroSchema.getFullName
        val fields = avroSchema.getFields.asScala.map { f =>
          val schemaType = toSqlTypeHelper(f.schema(), newRecordNames, avroOptions)
          StructField(f.name, schemaType.dataType, schemaType.nullable)
        }

        SchemaType(StructType(fields.toArray), nullable = false)

      case ARRAY =>
        val schemaType = toSqlTypeHelper(
          avroSchema.getElementType,
          existingRecordNames,
          avroOptions)
        SchemaType(
          ArrayType(schemaType.dataType, containsNull = schemaType.nullable),
          nullable = false)

      case MAP =>
        val schemaType = toSqlTypeHelper(avroSchema.getValueType, existingRecordNames, avroOptions)
        SchemaType(
          MapType(StringType, schemaType.dataType, valueContainsNull = schemaType.nullable),
          nullable = false)

      case UNION =>
        if (avroSchema.getTypes.asScala.exists(_.getType == NULL)) {
          // In case of a union with null, eliminate it and make a recursive call
          val remainingUnionTypes = AvroUtils.nonNullUnionBranches(avroSchema)
          if (remainingUnionTypes.size == 1) {
            toSqlTypeHelper(remainingUnionTypes.head, existingRecordNames, avroOptions)
              .copy(nullable = true)
          } else {
            toSqlTypeHelper(
              Schema.createUnion(remainingUnionTypes.asJava),
              existingRecordNames,
              avroOptions).copy(nullable = true)
          }
        } else avroSchema.getTypes.asScala.map(_.getType).toSeq match {
          case Seq(t1) =>
            toSqlTypeHelper(avroSchema.getTypes.get(0), existingRecordNames, avroOptions)
          case Seq(t1, t2) if Set(t1, t2) == Set(INT, LONG) =>
            SchemaType(LongType, nullable = false)
          case Seq(t1, t2) if Set(t1, t2) == Set(FLOAT, DOUBLE) =>
            SchemaType(DoubleType, nullable = false)
          case _ =>
            // When avroOptions.useStableIdForUnionType is false, convert complex unions to struct
            // types where field names are member0, member1, etc. This is consistent with the
            // behavior when converting between Avro and Parquet.
            // If avroOptions.useStableIdForUnionType is true, include type name in field names
            // so that users can drop or add fields and keep field name stable.
            val fieldNameSet : mutable.Set[String] = mutable.Set()
            val fields = avroSchema.getTypes.asScala.zipWithIndex.map {
              case (s, i) =>
                val schemaType = toSqlTypeHelper(s, existingRecordNames, avroOptions)

                val fieldName = if (avroOptions.useStableIdForUnionType) {
                  // Avro's field name may be case sensitive, so field names for two named type
                  // could be "a" and "A" and we need to distinguish them. In this case, we throw
                  // an exception.
                  val temp_name = s"member_${s.getName.toLowerCase(Locale.ROOT)}"
                  if (fieldNameSet.contains(temp_name)) {
                    throw new IncompatibleSchemaException(
                      "Cannot generate stable indentifier for Avro union type due to name " +
                      s"conflict of type name ${s.getName}")
                  }
                  fieldNameSet.add(temp_name)
                  temp_name
                } else {
                  s"member$i"
                }

                // All fields are nullable because only one of them is set at a time
                StructField(fieldName, schemaType.dataType, nullable = true)
            }

            SchemaType(StructType(fields.toArray), nullable = false)
        }

      case other => throw new IncompatibleSchemaException(s"Unsupported type $other")
    }
  }

  /**
   * Converts a Spark SQL schema to a corresponding Avro schema.
   *
   * @since 2.4.0
   */
  def toAvroType(
      catalystType: DataType,
      nullable: Boolean = false,
      recordName: String = "topLevelRecord",
      nameSpace: String = "")
    : Schema = {
    val builder = SchemaBuilder.builder()

    val schema = catalystType match {
      case BooleanType => builder.booleanType()
      case ByteType | ShortType | IntegerType => builder.intType()
      case LongType => builder.longType()
      case DateType =>
        LogicalTypes.date().addToSchema(builder.intType())
      case TimestampType =>
        LogicalTypes.timestampMicros().addToSchema(builder.longType())
      case TimestampNTZType =>
        LogicalTypes.localTimestampMicros().addToSchema(builder.longType())

      case FloatType => builder.floatType()
      case DoubleType => builder.doubleType()
      case StringType => builder.stringType()
      case NullType => builder.nullType()
      case d: DecimalType =>
        val avroType = LogicalTypes.decimal(d.precision, d.scale)
        val fixedSize = minBytesForPrecision(d.precision)
        // Need to avoid naming conflict for the fixed fields
        val name = nameSpace match {
          case "" => s"$recordName.fixed"
          case _ => s"$nameSpace.$recordName.fixed"
        }
        avroType.addToSchema(SchemaBuilder.fixed(name).size(fixedSize))

      case BinaryType => builder.bytesType()
      case ArrayType(et, containsNull) =>
        builder.array()
          .items(toAvroType(et, containsNull, recordName, nameSpace))
      case MapType(StringType, vt, valueContainsNull) =>
        builder.map()
          .values(toAvroType(vt, valueContainsNull, recordName, nameSpace))
      case st: StructType =>
        val childNameSpace = if (nameSpace != "") s"$nameSpace.$recordName" else recordName
        val fieldsAssembler = builder.record(recordName).namespace(nameSpace).fields()
        st.foreach { f =>
          val fieldAvroType =
            toAvroType(f.dataType, f.nullable, f.name, childNameSpace)
          fieldsAssembler.name(f.name).`type`(fieldAvroType).noDefault()
        }
        fieldsAssembler.endRecord()

      case ym: YearMonthIntervalType =>
        val ymIntervalType = builder.intType()
        ymIntervalType.addProp(CATALYST_TYPE_PROP_NAME, ym.typeName)
        ymIntervalType
      case dt: DayTimeIntervalType =>
        val dtIntervalType = builder.longType()
        dtIntervalType.addProp(CATALYST_TYPE_PROP_NAME, dt.typeName)
        dtIntervalType

      // This should never happen.
      case other => throw new IncompatibleSchemaException(s"Unexpected type $other.")
    }
    if (nullable && catalystType != NullType) {
      Schema.createUnion(schema, nullSchema)
    } else {
      schema
    }
  }
}

private[avro] class IncompatibleSchemaException(
  msg: String, ex: Throwable = null) extends Exception(msg, ex)

private[avro] class UnsupportedAvroTypeException(msg: String) extends Exception(msg)
