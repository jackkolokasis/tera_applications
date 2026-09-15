#!/usr/bin/env bash
###################################################
#
# file: conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @email:    kolokasis@ics.forth.gr
#
# Configuration for OpenSearch Lucene query-cache
# experiments using the geopoint-nyc-taxis branch.
#
###################################################

#### Workload ####################################################
WORKLOAD="${WORKLOAD:-nyc_taxis}"
TEST_PROCEDURE="${TEST_PROCEDURE:-append-no-conflicts}"
BENCHMARK_TASK="${BENCHMARK_TASK:-bbox,update_pressure}"

#### TeraHeap ####################################################
TERAHEAP_REPO="/home1/public/kolokasis/github/latest_version/smartsweep/teraheap_latest/teraheap/jdk17/build/linux-x86_64-server-release/images/jdk"
# TERAHEAP_REPO="/home1/public/kolokasis/github/latest_version/smartsweep/vanilla_teraheap/teraheap/jdk17u067/build/linux-x86_64-server-release/images/jdk"
MY_JAVA_HOME="${TERAHEAP_REPO}"
VANILLA_JAVA_HOME="${MY_JAVA_HOME}"

#### Paths #######################################################
BENCH_DIR="/home1/public/kolokasis/github/latest_version/smartsweep/benchmarks/tera_applications"
OPENSEARCH_DIR="${BENCH_DIR}/opensearch/opensearch-2.19.5"
OPENSEARCH_BENCH_DIR="${BENCH_DIR}/opensearch/query_cache/opensearch-benchmark-workloads-geopoint-nyc-taxis"
WORKLOAD_PATH="${OPENSEARCH_BENCH_DIR}/${WORKLOAD}"
export BENCHMARK_HOME="/mnt/spark/benchmark-home"

#### Devices #####################################################
DEV_DATA="nvme1n1"
MNT_DATA="/mnt/spark"
DEV_H2="nvme0n1"
MNT_H2="/mnt/fmap"

#### OpenSearch ##################################################
INDEX="nyc_taxis"
TARGET_HOST="sith4:9200"

#### JVM / Lucene query-cache sizing ############################
H1_SIZE_CSV="${H1_SIZE_CSV:-8}"
# Keep REQUEST_CACHE_SIZE_CSV as a backwards-compatible environment fallback,
# but -c and QUERY_CACHE_SIZE_CSV now refer to the Lucene query cache.
QUERY_CACHE_SIZE_CSV="${QUERY_CACHE_SIZE_CSV:-${REQUEST_CACHE_SIZE_CSV:-10%}}"
IFS=',' read -r -a H1_SIZE <<< "${H1_SIZE_CSV}"
IFS=',' read -r -a QUERY_CACHE_SIZE <<< "${QUERY_CACHE_SIZE_CSV}"
H1_H2_SIZE=( 1200 )

#### TeraHeap geometry ###########################################
CARD_SIZE=$((8 * 1024))
REGION_SIZE=$((32 * 1024 * 1024))
STRIPE_SIZE=$((REGION_SIZE / CARD_SIZE))
H2_FILE_SZ=200

#### GC ##########################################################
GC_THREADS=13

#### cgroup ######################################################
MEM_BUDGET="${MEM_BUDGET:-14G}"

#### bbox benchmark ##############################################
# These defaults match the geopoint-nyc-taxis test procedure:
#   warmup=50, iterations=100, target-throughput=3, clients=1.
# Use --tp-bbox to sweep throughput without editing this file.
TP_BBOX=( 3 )
TP_UPDATE=( 1 )
BBOX_SEARCH_CLIENTS="${BBOX_SEARCH_CLIENTS:-1}"
BBOX_WARMUP_ITERATIONS="${BBOX_WARMUP_ITERATIONS:-50}"
BBOX_ITERATIONS="${BBOX_ITERATIONS:-100}"

#### Query randomization #########################################
# OpenSearch Benchmark uses these knobs to generate repeatable randomized
# bounding boxes. repeat frequency is swept by run.sh -f.
REPEAT_FREQUENCIES=( 0.3 )
RANDOMIZATION_N="${RANDOMIZATION_N:-5000}"
RANDOMIZATION_ALPHA="${RANDOMIZATION_ALPHA:-1.0}"

TOTAL_CONFS=${#H1_SIZE[@]}
ENABLE_STATS=true
USER_EXTRA_JAVA_OPTS=""
