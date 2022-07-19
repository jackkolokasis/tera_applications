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

// scalastyle:off println
package org.apache.spark.examples

import org.apache.spark._
import org.apache.spark.SparkContext._
import org.apache.spark.storage._

object WordCount {
    def main(args: Array[String]) {
      val inputFile = args(0)
      val output = args(1)

      val conf = new SparkConf().setAppName("wordCount")

      // Create a Scala Spark Context.
      val sc = new SparkContext(conf)

      // Load our input data.
      val input = sc.textFile(inputFile, 4).cache()

      // Split up into words.
      val words = input.flatMap(line => line.split(" "))

      // Transform into word and count.
      val counts = words.map(word => (word, 1)).reduceByKey{case (x, y) => x + y}

      // Save the word count back out to a text file, causing evaluation.
      counts.saveAsTextFile(output)
    }
}
// scalastyle:on println
