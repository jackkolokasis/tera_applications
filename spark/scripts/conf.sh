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
USER=$(whoami)

# Dataset size "small" and "large"
DATA_SIZE=large
# JAVA Home
#MY_JAVA_HOME=$NATIVE_JDK17_AARCH64
#MY_JAVA_HOME="/spare/perpap/teraheap/jdk17u067/build/linux-aarch64-server-release/jdk"
MY_JAVA_HOME=$TERA_JDK17_AARCH64_RELEASE
#MY_JAVA_HOME="/opt/carvguest/asplos23_ae/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
#MY_JAVA_HOME="/spare/kolokasis/nativeJVM/jdk17u/build/linux-x86_64-server-release/jdk"
# Device for datasets directory : /dev/nvme3n1
DEV_BENCHMARK_DATASETS=$NVME_DEVICE_BENCHMARK_DATASETS
# Mount point for datasets directory : /mnt/datasets
MNT_BENCHMARK_DATASETS=$MOUNT_POINT_BENCHMARK_DATASETS
# Directory that contains datasets
#DATA_HDFS="file:///mnt/datasets/SparkBench"
DATA_HDFS="file://$MNT_BENCHMARK_DATASETS/SparkBench"
# Spark Version
SPARK_VERSION=3.3.0
# Number of partitions
NUM_OF_PARTITIONS=480
# Benchmark repo
#BENCH_DIR=/opt/carvguest/asplos23_ae/tera_applications
#BENCH_DIR=$TERA_APPLICATIONS_REPO
# Spark directory
SPARK_DIR=$TERA_APPLICATIONS_REPO/spark/spark-${SPARK_VERSION}
# Spark master log dir
MASTER_LOG_DIR=${SPARK_DIR}/logs
# Spark master log dir
MASTER_METRIC_FILE="${SPARK_DIR}/conf/metrics.properties"
# Spark master node
SPARK_MASTER=ampere
# Spark slave host name
SPARK_SLAVE=ampere
# Number of garbage collection threads
GC_THREADS=10
# Device for shuffle : nvme3n1
DEV_SHFL=$NVME_DEVICE_SHUFFLE
# Mount point for shuffle directory : /mnt/spark
MNT_SHFL=$MOUNT_POINT_H2
#MNT_SHFL=$MOUNT_POINT_H2
#Device for H2: nvme3n1
DEV_H2=$NVME_DEVICE_H2
# Mount point for H2 TeraHeap directory : /mnt/fmap
MNT_H2=$MOUNT_POINT_H2
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((32 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( REGION_SIZE / CARD_SIZE ))
# TeraCache file size in GB e.g 700 -> 700GB
H2_FILE_SZ=700
# Executor cores
EXEC_CORES=(16)
# SparkBench directory
SPARK_BENCH_DIR=$TERA_APPLICATIONS_REPO/spark/spark-bench
#Benchmark log
BENCH_LOG=$TERA_APPLICATIONS_REPO/spark/scripts/log.out
# Heap size for executors '-Xms' is in GB e.g., 54 -> 54GB
H1_SIZE=( 16 )
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
MEM_BUDGET=254G
# Spark memory fraction: 'spark.memory.storagefraction'
MEM_FRACTION=( 0.9 )
# Storage Level
S_LEVEL=("MEMORY_ONLY")
#S_LEVEL=("MEMORY_AND_DISK")
# TeraCache configuration size in Spark: 'spark.teracache.heap.size'
H1_H2_SIZE=( 1200 )
# Running benchmarks
BENCHMARKS=("PageRank")
# Number of executors
NUM_EXECUTORS=( 10 )
# Total Configurations
TOTAL_CONFS=${#H1_SIZE[@]}
# Enable statistics
ENABLE_STATS=true
# Choose transfer policy 
# The available policies are: "DefaultPolicy" and "SparkPrimitivePolicy"
TERAHEAP_POLICY="SparkPrimitivePolicy"
# Enable FlexHeap
ENABLE_FLEXHEAP=true
# Choose a flexheap policy
# 0: SimpleStateMachine
# 1: SimpleWaitVersion
# 7: Optimized
FLEXHEAP_POLICY=7
# We support two policies for calculating I/O wait:
# 0: we read the /proc/stat for single executor
# 1: we use getrusage() for multiple executors in flexheap
CPU_STATS_POLICY=1
USER_EXTRA_JAVA_OPTS=""
