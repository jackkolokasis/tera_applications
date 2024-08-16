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

package org.apache.spark.sql.catalyst.analysis

import org.apache.spark.sql.catalyst.expressions.{Cast, Expression, RuntimeReplaceable, SubqueryExpression, Unevaluable}
import org.apache.spark.sql.errors.QueryCompilationErrors
import org.apache.spark.sql.internal.SQLConf
import org.apache.spark.sql.types.TimestampType

sealed trait TimeTravelSpec

case class AsOfTimestamp(timestamp: Long) extends TimeTravelSpec
case class AsOfVersion(version: String) extends TimeTravelSpec

object TimeTravelSpec {
  def create(
      timestamp: Option[Expression],
      version: Option[String],
      conf: SQLConf) : Option[TimeTravelSpec] = {
    if (timestamp.nonEmpty && version.nonEmpty) {
      throw QueryCompilationErrors.invalidTimeTravelSpecError()
    } else if (timestamp.nonEmpty) {
      val ts = timestamp.get
      assert(ts.resolved && ts.references.isEmpty && !SubqueryExpression.hasSubquery(ts))
      if (!Cast.canAnsiCast(ts.dataType, TimestampType)) {
        throw QueryCompilationErrors.invalidTimestampExprForTimeTravel(
          "INVALID_TIME_TRAVEL_TIMESTAMP_EXPR.INPUT", ts)
      }
      val tsToEval = ts.transform {
        case r: RuntimeReplaceable => r.replacement
        case _: Unevaluable =>
          throw QueryCompilationErrors.invalidTimestampExprForTimeTravel(
            "INVALID_TIME_TRAVEL_TIMESTAMP_EXPR.UNEVALUABLE", ts)
        case e if !e.deterministic =>
          throw QueryCompilationErrors.invalidTimestampExprForTimeTravel(
            "INVALID_TIME_TRAVEL_TIMESTAMP_EXPR.NON_DETERMINISTIC", ts)
      }
      val tz = Some(conf.sessionLocalTimeZone)
      // Set `ansiEnabled` to false, so that it can return null for invalid input and we can provide
      // better error message.
      val value = Cast(tsToEval, TimestampType, tz, ansiEnabled = false).eval()
      if (value == null) {
        throw QueryCompilationErrors.invalidTimestampExprForTimeTravel(
          "INVALID_TIME_TRAVEL_TIMESTAMP_EXPR.INPUT", ts)
      }
      Some(AsOfTimestamp(value.asInstanceOf[Long]))
    } else if (version.nonEmpty) {
      Some(AsOfVersion(version.get))
    } else {
      None
    }
  }
}
