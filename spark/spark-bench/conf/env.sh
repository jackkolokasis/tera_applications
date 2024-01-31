# Spark Bench Suite
# Global settings - Configurations

USER=$(whoami)

# Spark Master
#master="sith4-fast"
master="ampere"

# A list of machines where the spark cluster is running
#MC_LIST="sith4-fast"
#MC_LIST="ampere"
MC_LIST=""
# Use these inputs for fileio
#DATA_HDFS=file:///mnt/datasets/SparkBench
DATA_HDFS=file://$SPARK_DATASETS
# Local dataset optional
DATASET_DIR="${DATA_HDFS}/dataset"

# Use this when run on Spark 2.3.0-kolokasis
SPARK_VERSION=2.3.0
[ -z "$SPARK_HOME" ] &&  export SPARK_HOME=$TERA_APPLICATIONS_REPO/spark/spark-3.3.0

SPARK_MASTER=spark://${master}:7077
#SPARK_MASTER=local[2]

SPARK_RPC_ASKTIMEOUT=10000
# Spark config in environment variable or aruments of spark-submit 
#SPARK_SERIALIZER=org.apache.spark.serializer.KryoSerializer
SPARK_RDD_COMPRESS=false
#SPARK_IO_COMPRESSION_CODEC=lzf

# Spark options in system.property or arguments of spark-submit 
SPARK_EXECUTOR_MEMORY=1200g
SPARK_EXECUTOR_INSTANCES=1
SPARK_EXECUTOR_CORES=16

# Storage levels, see :
STORAGE_LEVEL=MEMORY_ONLY

# For data generation
NUM_OF_PARTITIONS=256

# For running
NUM_TRIALS=1
