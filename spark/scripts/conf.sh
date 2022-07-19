#!/usr/bin/env bash

###################################################
#
# file: conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  27-02-2021 
# @email:    kolokasis@ics.forth.gr
#
# Experiments configurations. Setup these
# configurations before run
#
###################################################
# Datasets
DATA_HDFS="file:///mnt/datasets/SparkBench"
# Spark Version
SPARK_VERSION=2.3.0
# Number of Partitions
NUM_OF_PARTITIONS=256
# Benchmark repo
BENCH_DIR=/home1/public/kolokasis/tera_applications
# Spark directory
SPARK_DIR=${BENCH_DIR}/spark/spark-2.3.0
# Spark master log dir
MASTER_LOG_DIR=${SPARK_DIR}/logs
# Spark master log dir
MASTER_METRIC_FILE="${SPARK_DIR}/conf/metrics.properties"
# Spark master node
SPARK_MASTER=sith4-fast
# Spark slave host name
SPARK_SLAVE=sith4-fast
GC_THREADS=16
# Device for shuffle
DEV_SHFL=pmem0
MNT_SHFL=/mnt/spark
# Device for H2
DEV_FMAP=nvme1n1
MNT_FMAP=/mnt/fmap
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((256 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( ${REGION_SIZE} / ${CARD_SIZE}))
# TeraCache file size in GB e.g 800 -> 800GB
TC_FILE_SZ=900
# Executor cores
EXEC_CORES=( 16 )
# SparkBench directory
SPARK_BENCH_DIR=${BENCH_DIR}/spark/SparkBench
#Benchmark log
BENCH_LOG=${BENCH_DIR}/spark/log.out
# Heap size for executors '-Xms'
HEAP=( 54 )
# New generation size '-Xmn'
# if the value is 0: let the JVM to decide
# if the value > 0 : set the size of the New Generation based on the value
NEW_GEN=( 0 )
# DRAM shrink 200GB
RAMDISK=( 0 )
# Spark memory fraction: 'spark.memory.storagefraction'
MEM_FRACTON=( 0.9 )
# Storage Level
S_LEVEL=( "MEMORY_ONLY" )
# TeraCache configuration size in Spark: 'spark.teracache.heap.size'
TERACACHE=( 1200 )
# Running benchmarks
BENCHMARKS=( "LinearRegression" )
# Number of executors
EXECUTORS=1
# Total Configurations
TOTAL_CONFS=${#HEAP[@]}
