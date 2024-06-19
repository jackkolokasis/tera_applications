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
# JAVA Home
JAVA_PATH="/spare/kolokasis/dev/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
TERAHEAP_REPO="/spare/kolokasis/dev/teraheap"
# Benchmark repo
BENCH_DIR=/home1/public/kolokasis/lucene_bench/dimitris/tera_applications
# Dataset
DATASET=/mnt/fmap/indexOffHeap90GB
# Number of garbage collection threads
GC_THREADS=8
# Device for dataset
DEV_DATASET=md1
# Mount point for shuffle directory
MNT_DATASET=/mnt/spark
# Device for H2
DEV_H2=nvme1n1
# Mount point for H2 TeraHeap directory
MNT_H2=/mnt/fmap
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
H1_SIZE=( 8 )
MEM_BUDGET=10G
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
# Running benchmarks
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
#JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:+UseParallelGC -XX:ParallelGCThreads=16 -XX:+AlwaysPreTouch"
JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:+UseParallelGC -XX:ParallelGCThreads=16 -XX:+EnableFlexHeap -XX:FlexResizingPolicy=2 -XX:+ShowMessageBoxOnError -XX:FlexDRAMLimit=10737418240"
