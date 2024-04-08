#!/usr/bin/env bash

###################################################
#
# file: run_gen_dataset_tpcds.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  05-05-2024 
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to generate datase for TPC-DS
#
###################################################

. ./conf.sh

"${SPARK_DIR}"/bin/spark-submit \
  --class org.apache.spark.sql.GenTPCDSData \
  --conf spark.executor.instances="${NUM_EXECUTORS[0]}" \
  --conf spark.executor.cores="${EXEC_CORES[0]}" \
  --conf spark.executor.memory="${H1_SIZE[0]}"g \
  "${SPARK_DIR}"/sql/core/target/spark-sql_2.12-3.3.0-tests.jar \
  --master spark://sith4-fast:7077 \
  --dsdgenDir /opt/carvguest/asplos23_ae/tera_applications/spark/spark-tpcds/build/resources/main/binaries/Linux/x86_64/ \
  --location "${DATA_HDFS}"/tpcds \
  --scaleFactor 200 \
  --numPartitions 256
