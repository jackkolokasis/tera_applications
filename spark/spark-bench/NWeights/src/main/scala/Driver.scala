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

package src.main.scala

import org.apache.spark.storage.StorageLevel
import org.apache.log4j.Logger
import org.apache.log4j.Level
import org.apache.spark.{ SparkContext, SparkConf}
import org.apache.spark.SparkContext._
import org.apache.spark.graphx._
import org.apache.spark.graphx.lib._
import org.apache.spark.graphx.util.GraphGenerators
import org.apache.spark.rdd._

/**
 * Compute NWeight for Graph G(V, E) as defined below.
 *
 * Weight(1)(u, v) = edge(u, v)
 * Weight(n)(u, v) =
 *   Sum (over {x|there are edges (u, x) and (x, v)}) Weight(n-1)(u, x) * Weight(1)(x, v)
 *
 * Input is given in Text file format. Each line represents a Node and all out edges of that node
 * (edge weight specified)
 * <vertex> <vertex1>:<weight1>,<vertex2>:<weight2> ...)
 */

object NWeight extends Serializable{
 
  def parseArgs(args: Array[String]) = {
    if (args.length < 7) {
      System.err.println("Usage: <input> <output> <step> <max Out edges> " +
          "<no. of result partitions> <storageLevel> <model>")
      System.exit(1)
    }
    val input = args(0)
    val output =  args(1)
    val step = args(2).toInt
    val maxDegree = args(3).toInt
    val numPartitions = args(4).toInt
    val storageLevel = args(5).toInt match {
        case 0 => StorageLevel.OFF_HEAP
        case 1 => StorageLevel.DISK_ONLY
        case 2 => StorageLevel.DISK_ONLY_2
        case 3 => StorageLevel.MEMORY_ONLY
        case 4 => StorageLevel.MEMORY_ONLY_2
        case 5 => StorageLevel.MEMORY_ONLY_SER 
        case 6 => StorageLevel.MEMORY_ONLY_SER_2
        case 7 => StorageLevel.MEMORY_AND_DISK
        case 8 => StorageLevel.MEMORY_AND_DISK_2
        case 9 => StorageLevel.MEMORY_AND_DISK_SER
        case 10 => StorageLevel.MEMORY_AND_DISK_SER_2
        case _ => StorageLevel.MEMORY_AND_DISK
    }

    (input, output, step, maxDegree, numPartitions, storageLevel)
  }
  
  def main(args: Array[String]) {
    val (input, output, step, maxDegree, numPartitions, storageLevel) = parseArgs(args)
    
    Logger.getLogger("org.apache.spark").setLevel(Level.WARN)
    Logger.getLogger("org.eclipse.jetty.server").setLevel(Level.OFF)

    val sparkConf = new SparkConf()
    sparkConf.setAppName("NWeightGraphX")

    val sc = new SparkContext(sparkConf)

    GraphxNWeight.nweight(sc, input, output, step, maxDegree, numPartitions, storageLevel)

    sc.stop()
  }
}
