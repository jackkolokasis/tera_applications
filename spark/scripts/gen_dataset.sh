#!/usr/bin/env bash

###################################################
#
# file: run.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  20-01-2021 
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to run the experiments
#
###################################################

. ./conf.sh

##
# Description: 
#   Start Spark
##
start_spark() {
  "${SPARK_DIR}"/sbin/start-all.sh >> "${BENCH_LOG}" 2>&1
}

##
# Description: 
#   Stop Spark
##
stop_spark() {
  "${SPARK_DIR}"/sbin/stop-all.sh >> "${BENCH_LOG}" 2>&1
}

CUSTOM_BENCHMARK=false

./update_conf.sh -b ${CUSTOM_BENCHMARK}

start_spark

# Run benchmark and save output to tmp_out.txt
"${SPARK_BENCH_DIR}"/"${BENCHMARKS}"/bin/gen_data.sh >> "${BENCH_LOG}" 2>&1

stop_spark
