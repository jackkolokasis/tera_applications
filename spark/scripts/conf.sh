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
# Dataset size "small" and "large"
DATA_SIZE=small
# JAVA Home
MY_JAVA_HOME=${HOME}/github/teracache/openjdk-8/openjdk8/build/linux-x86_64-normal-server-release/jdk
# Directory that contains datasets
DATA_HDFS="file:///mnt/datasets/SparkBench"
# Spark Version
SPARK_VERSION=2.3.0
# Number of partitions
NUM_OF_PARTITIONS=256
# Benchmark repo
BENCH_DIR=${HOME}/tera_applications
# Spark directory
SPARK_DIR=${BENCH_DIR}/spark/spark-${SPARK_VERSION}
# Spark master log dir
MASTER_LOG_DIR=${SPARK_DIR}/logs
# Spark master log dir
MASTER_METRIC_FILE="${SPARK_DIR}/conf/metrics.properties"
# Spark master node
SPARK_MASTER=sith4-fast
# Spark slave host name
SPARK_SLAVE=sith4-fast
# Number of garbage collection threads
GC_THREADS=16
# Device for shuffle
DEV_SHFL=nvme0n1
# Mount point for shuffle directory
MNT_SHFL=/mnt/spark
# Device for H2
DEV_H2=nvme1n1
# Mount point for H2 TeraHeap directory
MNT_H2=/mnt/fmap
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((256 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( ${REGION_SIZE} / ${CARD_SIZE}))
# TeraCache file size in GB e.g 800 -> 800GB
H2_FILE_SZ=900
# Executor cores
EXEC_CORES=( 16 )
# SparkBench directory
SPARK_BENCH_DIR=${BENCH_DIR}/spark/SparkBench
#Benchmark log
BENCH_LOG=${BENCH_DIR}/spark/log.out
# Heap size for executors '-Xms' is in GB e.g., 54 -> 54GB
H1_SIZE=( 54 )
# DRAM shrink 200GB
RAMDISK=( 0 )
# Spark memory fraction: 'spark.memory.storagefraction'
MEM_FRACTION=( 0.9 )
# Storage Level
S_LEVEL=( "MEMORY_ONLY" )
# TeraCache configuration size in Spark: 'spark.teracache.heap.size'
H1_H2_SIZE=( 1200 )
# Running benchmarks
BENCHMARKS=( "PageRank" )
# Number of executors
NUM_EXECUTORS=( 1 )
# Total Configurations
TOTAL_CONFS=${#HEAP[@]}
