#!/usr/bin/env bash

#set -x
# Backup original conf.sh to restore later
#cp conf.sh conf.sh.backup
. ./conf.sh

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

BENCHMARKS=(ConnectedComponent LinearRegression LogisticRegression PageRank)
EXEC_CORES=16
GC_THREADS=10
H2_MOUNT_POINT=
SHUFFLE_MOUNT_POINT=
MASTER=
SLAVE=

sed -i "s/^EXEC_CORES=(.*)/EXEC_CORES=( $EXEC_CORES )/" conf.sh
sed -i "s/^GC_THREADS=.*/GC_THREADS=$GC_THREADS/" conf.sh
sed -i "s/^H1_SIZE=(.*)/H1_SIZE=( 200 )/" conf.sh
sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=254G/" conf.sh
sed -i "s/^S_LEVEL=(.*)/S_LEVEL=( \"MEMORY_ONLY\" )/" conf.sh

# Function to display usage message
function usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo
  echo "  -m, --master                        Specify the Spark master; eg. ampere."
  echo "  -s, --slave                         Specify the Spark slave; eg. ampere."
  echo "  -f, --h2-dir <path>                 Specify the path of the directory which contains the h2 backing file, eg. /spare2/perpap/fmap"
  echo "  -p, --shuffle-dir <path>            Specify the path of the directory which contains the spark shuffle directory, eg. /spare2/perpap/spark"
  echo "  -j, --java <path>                   Specify the path for JAVA_HOME enviroment variable"
  echo "  -d, --datasets <path>               Specify the path of the directory which contains the spark datasets, eg. /spare2/datasets"
  echo "  -h, --help                          Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./gen_dataset_batch.sh -d /spare2/datasets"
  echo "./gen_dataset_batch.sh -m sith2 -s sith2 -f /mnt/perpap/fmap -p /mnt/perpap/spark -j $HOME/openjdk/x86_64/jdk8u422-b05 -d /mnt/perpap/datasets"
}

function parse_script_arguments() {
  local OPTIONS=m:s:f:p:j:d:h
  local LONGOPTIONS=master:,slave:,h2-dir:,shuffle-dir:java:,datasets:,help

  # Use getopt to parse the options
  local PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")

  # Check for errors in getopt
  if [[ $? -ne 0 ]]; then
    exit ${ERRORS[INVALID_OPTION]}
  fi

  # Evaluate the parsed options
  eval set -- "$PARSED"

  while true; do
    case "$1" in
    -m | --master)
      MASTER="$2"
      sed -i "s|^SPARK_MASTER=.*|SPARK_MASTER=${MASTER}|" conf.sh
      shift 2
      ;;
    -s | --slave)
      SLAVE="$2"
      sed -i "s|^SPARK_SLAVE=.*|SPARK_SLAVE=${SLAVE}|" conf.sh
      shift 2
      ;;
    -f | --h2-dir)
      H2_MOUNT_POINT="$2"
      # Find the device name using df and process it to remove the /dev/ prefix
      DEVICE_NAME=$(df "$H2_MOUNT_POINT" | awk 'NR==2 {print $1}' | sed 's|/dev/||')
      # Update the conf.sh script with the device name for DEV_H2
      sed -i "s|^DEV_H2=.*|DEV_H2=${DEVICE_NAME}|" conf.sh
      # Update the conf.sh script with the mount point for MNT_H2
      sed -i "s|^MNT_H2=.*|MNT_H2=${H2_MOUNT_POINT}|" conf.sh
      shift 2
      ;;
    -p | --shuffle-dir)
      SHUFFLE_MOUNT_POINT="$2"
      # Find the device name using df and process it to remove the /dev/ prefix
      DEVICE_NAME=$(df "$SHUFFLE_MOUNT_POINT" | awk 'NR==2 {print $1}' | sed 's|/dev/||')
      # Update the conf.sh script with the device name for DEV_SHFL
      sed -i "s|^DEV_SHFL=.*|DEV_SHFL=${DEVICE_NAME}|" conf.sh
      # Update the conf.sh script with the mount point for MNT_SHFL
      sed -i "s|^MNT_SHFL=.*|MNT_SHFL=${SHUFFLE_MOUNT_POINT}|" conf.sh
      shift 2
      ;;
    -j | --java)
      if [[ -f "$2"/bin/java ]]; then
        sed -i "s|^MY_JAVA_HOME=.*|MY_JAVA_HOME=$2|" conf.sh
      else
        echo "Error: '$2/bin/java' does not exist."
        exit 1
      fi
      shift 2
      ;;
    -d | --datasets)
      DATASETS_MOUNT_POINT="$2"
      # Find the device name using df and process it to remove the /dev/ prefix
      DEVICE_NAME=$(df "$DATASETS_MOUNT_POINT" | awk 'NR==2 {print $1}' | sed 's|/dev/||')
      # Update the conf.sh script with the device name for DEV_BENCHMARK_DATASETS
      sed -i "s|^DEV_BENCHMARK_DATASETS=.*|DEV_BENCHMARK_DATASETS=${DEVICE_NAME}|" conf.sh
      # Update the conf.sh script with the mount point for MNT_BENCHMARK_DATASETS
      sed -i "s|^MNT_BENCHMARK_DATASETS=.*|MNT_BENCHMARK_DATASETS=${DATASETS_MOUNT_POINT}|" conf.sh
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Programming error"
      exit ${ERRORS[PROGRAMMING_ERROR]} 
      ;;
    esac
  done
}

parse_script_arguments "$@"

for BENCHMARK in "${BENCHMARKS[@]}"; do
  sed -i "s/^BENCHMARKS=(.*)/BENCHMARKS=( \"$BENCHMARK\" )/" conf.sh
  echo "Checking for dataset $MNT_BENCHMARK_DATASETS/SparkBench/$BENCHMARK"

  if [[ -d "$MNT_BENCHMARK_DATASETS/SparkBench/$BENCHMARK" ]]; then
    echo "$BENCHMARK dataset has already been generated."
  else
    echo "Generating $BENCHMARK dataset..."
    mkdir -p $MNT_BENCHMARK_DATASETS/SparkBench/$BENCHMARK
    ./gen_dataset.sh
  fi
done

# Restore the original conf.sh to leave no side effects
#cp conf.sh.backup conf.sh
#rm conf.sh.backup
