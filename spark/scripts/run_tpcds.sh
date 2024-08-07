#!/usr/bin/env bash

###################################################
#
# file: run_tpcds.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  06-04-2024 
# @email:    kolokasis@ics.forth.gr
#
# Exececute queries for TPC-DS workload
#
###################################################

. ./conf.sh

RUN_DIR=$1
HEAP_SIZE=$2
QUERY_NAME=$3

"${SPARK_DIR}"/bin/spark-submit \
  --conf spark.sql.test.master=spark://${SPARK_MASTER}:7077 \
  --conf spark.executor.instances="${NUM_EXECUTORS[0]}" \
  --conf spark.executor.cores="${EXEC_CORES[0]}" \
  --conf spark.executor.memory="${HEAP_SIZE}"g \
  --conf spark.sql.shuffle.partitions=32 \
  --jars "${SPARK_DIR}"/core/target/spark-core_2.12-3.3.0-tests.jar,"${SPARK_DIR}"/sql/catalyst/target/spark-catalyst_2.12-3.3.0-tests.jar \
  --class org.apache.spark.sql.execution.benchmark.TPCDSQueryBenchmark \
  "${SPARK_DIR}"/sql/core/target/spark-sql_2.12-3.3.0-tests.jar \
  --data-location "${DATA_HDFS}"/tpcds \
  --query-filter "${QUERY_NAME}" > "${RUN_DIR}"/tmp_out.txt 2>&1

# Search for the line containing the specified text and extract the numeric part using regex
duration=$(grep -Eo "Stopped after [0-9]+ iterations, ([0-9]+) ms" "${RUN_DIR}"/tmp_out.txt \
  | grep -Eo "[0-9]+" | tail -n 1)

# Convert from milliseconds to seconds
time_in_sec=$(echo "$duration / 1000" | bc)

echo ",,${time_in_sec}" >> "${RUN_DIR}"/total_time.txt
