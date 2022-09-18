#!/usr/bin/env bash
BENCHMARK_SUITE=/home1/public/kolokasis/tera_applications/neo4j/ldbc_graphalytics_platforms_neo4j-master/graphalytics-1.3.0-neo4j-0.1-SNAPSHOT
BENCHMARK_CONFIG="${BENCHMARK_SUITE}/config"
LOG="$BENCHMARK_SUITE/report/bench.log"
TH_STATS_FILE="$BENCHMARK_SUITE/report/teraHeap.txt"

####### DEVICES AND DIRECTORIES ######
# Directory that neo4j uses to create its database
NEO4J_DB_DIR=/mnt/spark
# Device for Neo4j database
DEV_NEO4J_DB=nvme0n1
# Directory with H2 TeraHeap file
TH_DIR=/mnt/fmap
# Device for TeraHeap or SD
DEV_TH=nvme1n1

####### TERAHEAP CONFIGURATION #######
# TeraHeap H2 file size in GB e.g. 900 -> 900GB
TH_FILE_SZ=900
####### BENCHMAMARK CONFIGURATION ####
# Dataset name
#DATASET_NAME=datagen-9_4-fb
DATASET_NAME=datagen-sf3k-fb
#DATASET_NAME=cit-Patents
# Heap size for executors '-Xms'
HEAP=11
# Size of H2 in GB
H1_AND_H2_SIZE=100
# Card table stripe size
STRIPE_SIZE=32768
# PageCache Size in GBs e.g. PAGE_CACHE=1 means 1G
PAGE_CACHE=1
# Garbage collection threads
GC_THREADS=16
# Benchmarks to run
#BENCHMARKS=( "pr" "bfs" "wcc" "cdlp" "sssp" )
BENCHMARKS=( "wcc" )
# cgset accepts K,M,G and KiB, MiB, GiB units for memory limit
MEM_BUDGET=14G
# Total Configurations
TOTAL_CONFS=1
