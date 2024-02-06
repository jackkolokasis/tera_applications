HOSTNAME=sith4-fast
JAVA_PATH=/spare/kolokasis/dev/teraheap/jdk8u345/build/linux-x86_64-normal-server-release/jdk
TERAHEAP_REPO=/spare/kolokasis/dev/teraheap
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
TH_FILE_SZ=900
# Heap size for executors '-Xms'
HEAP=40
# Garbage collection threads
GC_THREADS=16
# Number of compute threads
COMPUTE_THREADS=8
# Dataset name
#DATASET=cit-Patents
DATASET="datagen-9_0-fb" 
#DATASET="datagen-sf3k-fb" 
# Benchmarks to run
#BENCHMARKS=( "pr" "bfs" "wcc" "cdlp" "sssp" )
BENCHMARKS=( "cdlp" )
# Number of executors
EXECUTORS=1
# DRAM Limit
DRAM_LIMIT=55
# cgset accepts K,M,G and eiB, MiB, GiB units for memory limit
MEM_BUDGET=${DRAM_LIMIT}G
# Tera DRAM limit
TERA_DRAM_LIMIT=$((DRAM_LIMIT * 1024 * 1024 * 1024))
# Total Configurations
TOTAL_CONFS=1
# Card segment size for H2
CARD_SIZE=$((8 * 1024))
# Region size for H2
REGION_SIZE=$((32 * 1024 * 1024))
# Stripe size for H2
STRIPE_SIZE=$((REGION_SIZE / CARD_SIZE ))
# Print TeraHeap statistics for cards. When this flag is enabled the
# PRINT_EXTENDED_STATS should be disabled
PRINT_STATS=true
# Print TeraHeap extended statistics includeing dirty cards. When this
# flag is enabled the PRINT_STATS should be disabled
PRINT_EXTENDED_STATS=false
# These flags are for DynaHeap
DYNAHEAP=true
# Resizing policy:
#   0: Simple policy
#   1: Simple wait policy
#   2: Agressive Grow
#   3: Aggressive Shrink
#   4: Full optimized wait state
#   5: Shrink after grow policy
#   6: Optimize Grow state machine;
#   7: Full optimized
TERA_RESIZING_POLICY=7
