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

package org.apache.spark.sql.execution.streaming.state

import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.Path

import org.apache.spark.internal.Logging
import org.apache.spark.sql.execution.streaming.CheckpointFileManager
import org.apache.spark.sql.execution.streaming.state.SchemaHelper.{SchemaReader, SchemaWriter}
import org.apache.spark.sql.internal.SQLConf
import org.apache.spark.sql.types.{DataType, StructType}

case class StateSchemaNotCompatible(message: String) extends Exception(message)

class StateSchemaCompatibilityChecker(
    providerId: StateStoreProviderId,
    hadoopConf: Configuration) extends Logging {

  private val storeCpLocation = providerId.storeId.storeCheckpointLocation()
  private val fm = CheckpointFileManager.create(storeCpLocation, hadoopConf)
  private val schemaFileLocation = schemaFile(storeCpLocation)
  private val schemaWriter =
    SchemaWriter.createSchemaWriter(StateSchemaCompatibilityChecker.VERSION)

  fm.mkdirs(schemaFileLocation.getParent)

  def check(keySchema: StructType, valueSchema: StructType): Unit = {
    check(keySchema, valueSchema, ignoreValueSchema = false)
  }

  def check(keySchema: StructType, valueSchema: StructType, ignoreValueSchema: Boolean): Unit = {
    if (fm.exists(schemaFileLocation)) {
      logDebug(s"Schema file for provider $providerId exists. Comparing with provided schema.")
      val (storedKeySchema, storedValueSchema) = readSchemaFile()
      if (storedKeySchema.equals(keySchema) &&
        (ignoreValueSchema || storedValueSchema.equals(valueSchema))) {
        // schema is exactly same
      } else if (!schemasCompatible(storedKeySchema, keySchema) ||
        (!ignoreValueSchema && !schemasCompatible(storedValueSchema, valueSchema))) {
        val errorMsgForKeySchema = s"- Provided key schema: $keySchema\n" +
          s"- Existing key schema: $storedKeySchema\n"

        // If it is requested to skip checking the value schema, we also don't expose the value
        // schema information to the error message.
        val errorMsgForValueSchema = if (!ignoreValueSchema) {
          s"- Provided value schema: $valueSchema\n" +
            s"- Existing value schema: $storedValueSchema\n"
        } else {
          ""
        }
        val errorMsg = "Provided schema doesn't match to the schema for existing state! " +
          "Please note that Spark allow difference of field name: check count of fields " +
          "and data type of each field.\n" +
          errorMsgForKeySchema +
          errorMsgForValueSchema +
          s"If you want to force running query without schema validation, please set " +
          s"${SQLConf.STATE_SCHEMA_CHECK_ENABLED.key} to false.\n" +
          "Please note running query with incompatible schema could cause indeterministic" +
          " behavior."
        logError(errorMsg)
        throw StateSchemaNotCompatible(errorMsg)
      } else {
        logInfo("Detected schema change which is compatible. Allowing to put rows.")
      }
    } else {
      // schema doesn't exist, create one now
      logDebug(s"Schema file for provider $providerId doesn't exist. Creating one.")
      createSchemaFile(keySchema, valueSchema)
    }
  }

  private def schemasCompatible(storedSchema: StructType, schema: StructType): Boolean =
    DataType.equalsIgnoreNameAndCompatibleNullability(schema, storedSchema)

  // Visible for testing
  private[sql] def readSchemaFile(): (StructType, StructType) = {
    val inStream = fm.open(schemaFileLocation)
    try {
      val versionStr = inStream.readUTF()
      val schemaReader = SchemaReader.createSchemaReader(versionStr)
      schemaReader.read(inStream)
    } catch {
      case e: Throwable =>
        logError(s"Fail to read schema file from $schemaFileLocation", e)
        throw e
    } finally {
      inStream.close()
    }
  }

  private def createSchemaFile(keySchema: StructType, valueSchema: StructType): Unit = {
    createSchemaFile(keySchema, valueSchema, schemaWriter)
  }

  // Visible for testing
  private[sql] def createSchemaFile(
      keySchema: StructType,
      valueSchema: StructType,
      schemaWriter: SchemaWriter): Unit = {
    val outStream = fm.createAtomic(schemaFileLocation, overwriteIfPossible = false)
    try {
      schemaWriter.write(keySchema, valueSchema, outStream)
      outStream.close()
    } catch {
      case e: Throwable =>
        logError(s"Fail to write schema file to $schemaFileLocation", e)
        outStream.cancel()
        throw e
    }
  }

  private def schemaFile(storeCpLocation: Path): Path =
    new Path(new Path(storeCpLocation, "_metadata"), "schema")
}

object StateSchemaCompatibilityChecker {
  val VERSION = 2
}
