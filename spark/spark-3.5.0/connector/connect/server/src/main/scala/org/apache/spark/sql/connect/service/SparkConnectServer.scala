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

package org.apache.spark.sql.connect.service

import java.net.InetSocketAddress

import scala.collection.convert.ImplicitConversions._

import org.apache.spark.internal.Logging
import org.apache.spark.sql.SparkSession

/**
 * The Spark Connect server
 */
object SparkConnectServer extends Logging {
  def main(args: Array[String]): Unit = {
    // Set the active Spark Session, and starts SparkEnv instance (via Spark Context)
    logInfo("Starting Spark session.")
    val session = SparkSession.builder.getOrCreate()
    try {
      try {
        SparkConnectService.start(session.sparkContext)
        SparkConnectService.server.getListenSockets.foreach { sa =>
          val isa = sa.asInstanceOf[InetSocketAddress]
          logInfo(
            s"Spark Connect server started at: " +
              s"${isa.getAddress.getHostAddress}:${isa.getPort}")
        }
      } catch {
        case e: Exception =>
          logError("Error starting Spark Connect server", e)
          System.exit(-1)
      }
      SparkConnectService.server.awaitTermination()
    } finally {
      session.stop()
      SparkConnectService.uiTab.foreach(_.detach())
    }
  }
}
