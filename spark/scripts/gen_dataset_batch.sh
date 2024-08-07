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
#H1_SIZE=64
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
  echo "  -j, --java <path>                   Specify the path for JAVA_HOME enviroment variable"
  echo "  -d, --datasets <path>               Specify the path of the directory which contains the spark datasets, eg. /spare2/datasets"
  echo "  -h, --help                          Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./gen_dataset_batch.sh -d /spare2/datasets"
}

function parse_script_arguments() {
  local OPTIONS=j:d:h
  local LONGOPTIONS=java:,datasets:,help

  # Use getopt to parse the options
  local PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")

  # Check for errors in getopt
  if [[ $? -ne 0 ]]; then
    return ${ERRORS[INVALID_OPTION]} 2>/dev/null || exit ${ERRORS[INVALID_OPTION]}
  fi

  # Evaluate the parsed options
  eval set -- "$PARSED"

  while true; do
    case "$1" in
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
      return ${ERRORS[PROGRAMMING_ERROR]} 2>/dev/null || exit ${ERRORS[PROGRAMMING_ERROR]} # This will return if sourced, and exit if run as a standalone script
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
