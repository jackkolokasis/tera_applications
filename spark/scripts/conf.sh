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
DATA_SIZE=large
# JAVA Home
MY_JAVA_HOME="/spare/perpap/teraheap/jdk17u067/build/linux-aarch64-server-release/jdk"
#MY_JAVA_HOME="/opt/carvguest/asplos23_ae/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
#MY_JAVA_HOME="/spare/kolokasis/nativeJVM/jdk17u/build/linux-x86_64-server-release/jdk"
# Directory that contains datasets
#DATA_HDFS="file:///mnt/datasets/SparkBench"
DATA_HDFS="file:///spare/perpap/datasets/SparkBench"
# Spark Version
SPARK_VERSION=3.3.0
# Number of partitions
NUM_OF_PARTITIONS=256
# Benchmark repo
#BENCH_DIR=/opt/carvguest/asplos23_ae/tera_applications
BENCH_DIR=/spare/perpap/tera_applications
# Spark directory
SPARK_DIR=${BENCH_DIR}/spark/spark-${SPARK_VERSION}
# Spark master log dir
MASTER_LOG_DIR=${SPARK_DIR}/logs
# Spark master log dir
MASTER_METRIC_FILE="${SPARK_DIR}/conf/metrics.properties"
# Spark master node
#SPARK_MASTER=sith4-fast
SPARK_MASTER=ampere
# Spark slave host name
#SPARK_SLAVE=sith4-fast
SPARK_SLAVE=ampere
# Number of garbage collection threads
GC_THREADS=8
# Device for shuffle
DEV_SHFL=md1
# Mount point for shuffle directory
#MNT_SHFL=/mnt/spark
MNT_SHFL=/spare/perpap/spark
# Device for H2
DEV_H2=nvme3n1
# Mount point for H2 TeraHeap directory
MNT_H2=/mnt/fmap
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((256 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( REGION_SIZE / CARD_SIZE ))
# TeraCache file size in GB e.g 800 -> 800GB
H2_FILE_SZ=800
# Executor cores
EXEC_CORES=( 8 )
# SparkBench directory
SPARK_BENCH_DIR=${BENCH_DIR}/spark/spark-bench
#Benchmark log
BENCH_LOG=${BENCH_DIR}/spark/scripts/log.out
# Heap size for executors '-Xms' is in GB e.g., 54 -> 54GB
H1_SIZE=(38)
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
MEM_BUDGET=54G
# Spark memory fraction: 'spark.memory.storagefraction'
MEM_FRACTION=( 0.9 )
# Storage Level
S_LEVEL=( "MEMORY_ONLY" )
# TeraCache configuration size in Spark: 'spark.teracache.heap.size'
H1_H2_SIZE=( 1200 )
# Running benchmarks
BENCHMARKS=( "LinearRegression" )
# Number of executors
NUM_EXECUTORS=( 1 )
# Total Configurations
TOTAL_CONFS=${#H1_SIZE[@]}
