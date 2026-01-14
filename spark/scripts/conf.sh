#!/usr/bin/env bash
#set -x
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
###################################################TERAHEAP_HOME=$HOME/teraheap
USER=$(whoami)
export TERA_APPS_HOME="$(pwd)/../.."
#export TERAHEAP_HOME=
TERAHEAP_HOME=/spare/s1/perpap/melidonis_g1/teraheap
#TERAHEAP_HOME=/spare/s1/perpap/melidonis_g1/teraheap
export LIBRARY_PATH=${TERAHEAP_HOME}/allocator/lib:${TERAHEAP_HOME}/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_HOME}/allocator/lib:${TERAHEAP_HOME}/tera_malloc/lib:${TERAHEAP_HOME}/hsdis:/$LD_LIBRARY_PATH
#export LD_LIBRARY_PATH=/spare/s1/perpap/testing_melidonis/teraheap/tests:$LD_LIBRARY_PATH
#export PATH=${TERAHEAP_HOME}/allocator/include:${TERAHEAP_HOME}/tera_malloc/include:$PATH
#export C_INCLUDE_PATH=${TERAHEAP_HOME}/allocator/include:${TERAHEAP_HOME}/tera_malloc/include:$C_INCLUDE_PATH
#export CPLUS_INCLUDE_PATH=${TERAHEAP_HOME}/allocator/include:${TERAHEAP_HOME}/tera_malloc/include:$CPLUS_INCLUDE_PATH

# Dataset size "small" and "large"
DATA_SIZE=large
# JAVA Home
#MY_JAVA_HOME=/spare/s1/perpap/melidonis_g1/teraheap/jdk17/build/linux-aarch64-server-release/jdk
#MY_JAVA_HOME=/spare/s1/perpap/melidonis_g1/teraheap/jdk8u345/build/linux-aarch64-normal-server-release/jdk
MY_JAVA_HOME=/spare/s1/perpap/melidonis_g1/teraheap/jdk17/build/linux-aarch64-server-release/jdk
#MY_JAVA_HOME=/spare/s1/perpap/testing_melidonis/teraheap/jdk17/build/linux-aarch64-server-release/jdk
# Device for datasets directory : /dev/nvme3n1
DEV_BENCHMARK_DATASETS=md1
# Mount point for datasets directory : /mnt/datasets
MNT_BENCHMARK_DATASETS=/spare/s1/perpap/datasets_1024
# Directory that contains datasets
DATA_HDFS="file://$MNT_BENCHMARK_DATASETS/SparkBench"
# Spark Version
SPARK_VERSION=3.3.0
# Number of partitions
NUM_OF_PARTITIONS=1024
# Benchmark repo
#BENCH_DIR=/opt/carvguest/asplos23_ae/tera_applications
#BENCH_DIR=$TERA_APPS_HOME
# Spark directory
SPARK_DIR=$TERA_APPS_HOME/spark/spark-${SPARK_VERSION}
# Spark master log dir
MASTER_LOG_DIR=${SPARK_DIR}/logs
# Spark master log dir
MASTER_METRIC_FILE="${SPARK_DIR}/conf/metrics.properties"
# Spark master node
SPARK_MASTER=ampere
# Spark slave host name
SPARK_SLAVE=ampere
# Number of garbage collection threads
GC_THREADS=8
GC=native_g1
# Device for shuffle : nvme3n1
DEV_SHFL=md1
# Mount point for shuffle directory : /mnt/spark
MNT_SHFL=/spare/s1/perpap/spark
#Device for H2: nvme3n1
DEV_H2=md1
# Mount point for H2 TeraHeap directory : /mnt/fmap
MNT_H2=/spare/s1/perpap/fmap
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((256 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$((REGION_SIZE / CARD_SIZE))
# TeraCache file size in GB e.g 700 -> 700GB
H2_FILE_SZ=1000
# Number of executors
NUM_EXECUTORS=( 1 )
#NUM_EXECUTORS=( 8 )
# Executor cores
EXEC_CORES=(8)
#EXEC_CORES=(20)
# SparkBench directory
SPARK_BENCH_DIR=$TERA_APPS_HOME/spark/spark-bench
#Benchmark log
BENCH_LOG=$TERA_APPS_HOME/spark/scripts/log.out
#Util directory
DISABLE_CORES_DIR=$TERA_APPS_HOME/util
# Heap size for executors '-Xms' is in GB e.g., 54 -> 54GB
#H1_SIZE=( 224 )
H1_SIZE=( 54 )
# per-executor "soft" budget in GB (heap + overhead)
#PER_EXEC_BUDGET=28
#MEM_BUDGET="$(( NUM_EXECUTORS * PER_EXEC_BUDGET ))G"
MEM_BUDGET=70G
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
# total cluster budget ≈ 8 * 28 = 224GB
#MEM_BUDGET=224G
#MEM_OVERHEAD=20G
MEM_OVERHEAD=20
# Spark memory fraction: 'spark.memory.storagefraction'
#MEM_FRACTION=( 0.9 )
MEM_FRACTION=(0.5) #melidonis G1
# Storage Level
#S_LEVEL=( "MEMORY_ONLY" )
S_LEVEL=("MEMORY_AND_DISK")
# TeraCache configuration size in Spark: 'spark.teracache.heap.size'
H1_H2_SIZE=( 1200 )
#H1_H2_SIZE=$((1200 / NUM_EXECUTORS ))
# Size of H1 regions (MBs); 
# Graphx benchmarks require 16MB regions(Pagerank, ConnectedComponents). 
# ML benchmarks require 8MB regions(LinearRegression, LogisticRegression).
H1_MEM_REGION_SIZE=8
# Running benchmarks
#BENCHMARKS=("ConnectedComponent" "PageRank" "LinearRegression" "LogisticRegression")
BENCHMARKS=("LogisticRegression")
# Total Configurations
TOTAL_CONFS=${#H1_SIZE[@]}
# Enable statistics
ENABLE_STATS=true
#ENABLE_STATS=false
# Choose H2 write policy
# The available policies are: "AsyncWritePolicy" and "SyncWritePolicy"
TERAHEAP_WRITE_POLICY=AsyncWritePolicy
# Choose transfer policy
# The available policies are: "DefaultPolicy" and "SparkPrimitivePolicy"
#TERAHEAP_POLICY="DefaultPolicy"
TERAHEAP_POLICY="SparkPrimitivePolicy" #melidonis G1
# Enable FlexHeap
ENABLE_FLEXHEAP=false
USE_CGROUPS=false
USE_NUMA=false
#USE_PARALLEL_H2_ALLOCATOR=true
ENABLE_PARALLEL_H2_COMPACT=false
ENABLE_PARALLEL_H2_PRECOMPACT=false
# Choose a flexheap policy
# 0: SimpleStateMachine
# 1: SimpleWaitVersion
# 7: Optimized
FLEXHEAP_POLICY=7
# We support two policies for calculating I/O wait:
# 0: we read the /proc/stat for single executor
# 1: we use getrusage() for multiple executors in flexheap
CPU_STATS_POLICY=1
#CPU_STATS_POLICY=1 #melidonis G1
#USER_EXTRA_JAVA_OPTS="-XX:+UseG1GC -Xlog:gc*:file=gc.log::filecount=1,filesize=200M"
#USER_EXTRA_JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=detail -XX:MaxDirectMemorySize=4g -XX:+ExitOnOutOfMemoryError -XX:G1HeapRegionSize=${H1_MEM_REGION_SIZE}m"
USER_EXTRA_JAVA_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=detail -XX:+UseG1GC -XX:MaxGCPauseMillis=5000 -Xlog:gc*:file=gc.log::filecount=1,filesize=200M -XX:-ResizePLAB -XX:G1HeapRegionSize=${H1_MEM_REGION_SIZE}m"
#USER_EXTRA_JAVA_OPTS="-Xlog:gc*:file=gc.log::filecount=1,filesize=200M"
#melidonis G1
#USER_EXTRA_JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=5000 -Xlog:gc*:file=gc.log::filecount=1,filesize=200M -XX:-ResizePLAB -XX:G1HeapRegionSize=${H1_MEM_REGION_SIZE}m -XX:NativeMemoryTracking=detail -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly -XX:+PrintInterpreter -XX:+PrintNMethods"
