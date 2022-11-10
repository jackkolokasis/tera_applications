BENCHMARK_SUITE="/opt/kolokasis/tera_applications/giraph/graphalytics-platforms-giraph/graphalytics-1.2.0-giraph-0.2-SNAPSHOT"
BENCHMARK_CONFIG="${BENCHMARK_SUITE}/config"
LOG="$BENCHMARK_SUITE/report/bench.log"
HADOOP="/opt/kolokasis/tera_applications/giraph/hadoop-2.4.0"
ZOOKEEPER="/opt/kolokasis/tera_applications/giraph/zookeeper-3.4.1"
DATASET_DIR="/mnt/datasets"
RAMDISK_SCRIPT_DIR=/tmp
RAMDISK_DIR=/mnt/ramdisk
# Directory that zookeeper use during experiment
ZOOKEEPER_DIR=/mnt/fmap
# Directory that contains the file for teraheap. In case of off-heap experiments
# these directory contains the 
TH_DIR=/mnt/fmap
# Device for HDFS
DEV_HDFS=md1
# Device for Zookeeper
DEV_ZK=md0
# Device for TeraHeap or SD
DEV_TH=md0
# TeraHeap file size in GB e.g. 900 -> 900GB
TH_FILE_SZ=700
# Heap size for executors '-Xms'
HEAP=60
# Garbage collection threads
GC_THREADS=16
# Number of compute threads
COMPUTE_THREADS=8
# Benchmarks to run
#BENCHMARKS=( "pr" "bfs" "wcc" "cdlp" "sssp" )
BENCHMARKS=( "wcc" )
# Number of executors
EXECUTORS=1
# Number of executors
RAMDISK=0
# Total Configurations
TOTAL_CONFS=1
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((16 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$(( REGION_SIZE / CARD_SIZE ))
