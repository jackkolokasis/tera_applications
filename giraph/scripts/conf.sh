HOSTNAME=sith4-fast
BENCHMARK_SUITE="/opt/carvguest/asplos23_ae/tera_applications/giraph/graphalytics-platforms-giraph/graphalytics-1.2.0-giraph-0.2-SNAPSHOT"
BENCHMARK_CONFIG="${BENCHMARK_SUITE}/config"
LOG="$BENCHMARK_SUITE/report/bench.log"
HADOOP="/opt/carvguest/asplos23_ae/tera_applications/giraph/hadoop-2.4.0"
ZOOKEEPER="/opt/carvguest/asplos23_ae/tera_applications/giraph/zookeeper-3.4.1"
HADOOP="/opt/carvguest/asplos23_ae/tera_applications/giraph/hadoop-2.4.0"
DATASET_DIR="/mnt/datasets"
RAMDISK_SCRIPT_DIR=/tmp
RAMDISK_DIR=/mnt/ramdisk
# Directory that zookeeper use during experiment
ZOOKEEPER_DIR=/mnt/spark
# Directory that contains the file for teraheap. In case of off-heap experiments
# these directory contains the 
TH_DIR=/mnt/fmap
# Device for HDFS
DEV_HDFS=md0
# Device for Zookeeper
DEV_ZK=nvme0n1
# Device for TeraHeap or SD
DEV_TH=nvme1n1
# TeraHeap file size in GB e.g. 900 -> 900GB
TH_FILE_SZ=450
# Heap size for executors '-Xms'
HEAP=35
# Garbage collection threads
GC_THREADS=16
# Number of compute threads
COMPUTE_THREADS=8
# Dataset name
DATASET="datagen-9_0-fb" 
# Benchmarks to run
#BENCHMARKS=( "pr" "bfs" "wcc" "cdlp" "sssp" )
BENCHMARKS=( "bfs" )
# Number of executors
EXECUTORS=1
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
MEM_BUDGET=65G
# Total Configurations
TOTAL_CONFS=1
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((32 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$((REGION_SIZE / CARD_SIZE ))
