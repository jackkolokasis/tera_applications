#!/usr/bin/env bash

###################################################
#
# file: conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  19-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Experiments configurations. Setup these
# configurations before run
#
###################################################

# USER
LOGIN=$(whoami)
# Group ID for the cgroups
GROUP_ID=carvsudo
# JAVA Home
JAVA_PATH="/home1/public/kolokasis/github/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
# Repo to TeraHeap
TERAHEAP_REPO="/home1/public/kolokasis/github/teraheap"
# Benchmark repo
BENCH_DIR=/home1/public/kolokasis/lucene_bench/dimitris/tera_applications
# Dataset
DATASET=/mnt/fmap/indexOffHeap90GB
# Number of garbage collection threads
GC_THREADS=8
# Device for dataset
DEV_DATASET=nvme1n1
# Directory with queries used to run Lucene workloads
QUERIES_DIR=${TERAHEAP_REPO}/lucene/scripts/queries
# Device for H2
DEV_H2=nvme0n1
# Mount point for H2 TeraHeap directory
MNT_H2=/mnt/spark
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((256 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( REGION_SIZE / CARD_SIZE ))
# TeraCache file size in GB e.g 800 -> 800GB
H2_FILE_SZ=700
#Benchmark log
BENCH_LOG=${BENCH_DIR}/lucene/scripts/log.out
# Heap size for executors '-Xms' is in GB e.g., 54 -> 54GB
H1_SIZE=( 4 )
MEM_BUDGET=5G
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
# Running benchmarks
# M1:
# M2:
# M3:
# M4:
# M5:
# M6:
BENCHMARKS=( "MS_ML" )
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
# 0: we read the /proc/stat
# 1: we use getrusage()
CPU_STATS_POLICY=1
#JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:+UseParallelGC -XX:ParallelGCThreads=16 -XX:+AlwaysPreTouch -Xmx${H1_SIZE}g -Xms${H1_SIZE}g"
JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:+UseParallelGC -XX:ParallelGCThreads=16 -XX:+EnableFlexHeap -XX:FlexResizingPolicy=2 -XX:+ShowMessageBoxOnError -XX:FlexDRAMLimit=5368709120 -Xmx${H1_SIZE}g "
# Options for TeraHeap
#tc_size=$(( (900 - H1_SIZE) * 1024 * 1024 * 1024 ))
#JAVA_OPTS="-XX:-ClassUnloading -XX:+UseParallelGC -XX:ParallelGCThreads=16 -XX:+EnableTeraHeap \
#  -XX:TeraHeapSize=${tc_size} -Xmx=900g -Xms${H1_SIZE}g -XX:-UseCompressedOops -XX:-UseCompressedClassPointers \
#  -XX:+TeraHeapStatistics -Xlogth:teraHeap.txt -XX:TeraHeapPolicy="DefaultPolicy" -XX:TeraStripeSize=${STRIPE_SIZE} \
#  -XX:+ShowMessageBoxOnError -XX:AllocateH2At="/mnt/fmap/" -XX:H2FileSize=751619276800 -XX:TeraCPUStatsPolicy=1"
