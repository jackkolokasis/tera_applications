#!/usr/bin/env bash

set -x

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

BENCHMARKS=("LinearRegression" "LogisticRegression" "ConnectedComponent" "PageRank")
EXECUTOR_CORES=(80 40 20 10)
#EXECUTOR_CORES=(160 80 40 32 20 16 8 4 2 1)
#STORAGE_LEVELS=("MEMORY_ONLY" "MEMORY_AND_DISK")
#STORAGE_LEVELS=("MEMORY_AND_DISK")
STORAGE_LEVELS=("MEMORY_ONLY")
RESULTS_PATH=
DATASETS_MOUNT_POINT=
H2_MOUNT_POINT=
SHUFFLE_MOUNT_POINT=
ITERATIONS=1
CONFIG_FILE=
JAVA_BUILD="release"
MASTER=
SLAVE=
EXECUTION="t"
JDK_PATH=

# Define a "delimiter" to simulate multidimensional associative arrays
delimiter=":"

# Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
# ["BENCHMARK:CORES"]="H1_SIZE:MEM_BUDGET"
declare -A CONFIG_MAP=(
  ["LinearRegression${delimiter}1"]="160:200"
  ["LinearRegression${delimiter}2"]="160:200"
  ["LinearRegression${delimiter}4"]="160:200"
  ["LinearRegression${delimiter}8"]="160:200"
  ["LinearRegression${delimiter}10"]="160:200"
  ["LinearRegression${delimiter}16"]="160:200"
  ["LinearRegression${delimiter}20"]="160:200"
  ["LinearRegression${delimiter}32"]="160:200"
  ["LinearRegression${delimiter}40"]="160:200"
  ["LinearRegression${delimiter}60"]="160:200"
  ["LinearRegression${delimiter}80"]="160:200"
  ["LinearRegression${delimiter}100"]="160:200"
  ["LinearRegression${delimiter}120"]="160:200"
  ["LinearRegression${delimiter}140"]="160:200"
  ["LinearRegression${delimiter}160"]="160:200"
  ["LogisticRegression${delimiter}1"]="160:200"
  ["LogisticRegression${delimiter}2"]="160:200"
  ["LogisticRegression${delimiter}4"]="160:200"
  ["LogisticRegression${delimiter}8"]="160:200"
  ["LogisticRegression${delimiter}10"]="160:200"
  ["LogisticRegression${delimiter}16"]="160:200"
  ["LogisticRegression${delimiter}20"]="160:200"
  ["LogisticRegression${delimiter}32"]="160:200"
  ["LogisticRegression${delimiter}40"]="160:200"
  ["LogisticRegression${delimiter}60"]="160:200"
  ["LogisticRegression${delimiter}80"]="160:200"
  ["LogisticRegression${delimiter}100"]="160:200"
  ["LogisticRegression${delimiter}120"]="160:200"
  ["LogisticRegression${delimiter}140"]="160:200"
  ["LogisticRegression${delimiter}160"]="160:200"
  ["PageRank${delimiter}1"]="160:200"
  ["PageRank${delimiter}2"]="160:200"
  ["PageRank${delimiter}4"]="160:200"
  ["PageRank${delimiter}8"]="160:200"
  ["PageRank${delimiter}10"]="160:200"
  ["PageRank${delimiter}16"]="160:200"
  ["PageRank${delimiter}20"]="160:200"
  ["PageRank${delimiter}32"]="160:200"
  ["PageRank${delimiter}40"]="160:200"
  ["PageRank${delimiter}60"]="160:200"
  ["PageRank${delimiter}80"]="160:200"
  ["PageRank${delimiter}100"]="160:200"
  ["PageRank${delimiter}120"]="160:200"
  ["PageRank${delimiter}140"]="160:200"
  ["PageRank${delimiter}160"]="160:200"
  ["ConnectedComponent${delimiter}1"]="160:200"
  ["ConnectedComponent${delimiter}2"]="160:200"
  ["ConnectedComponent${delimiter}4"]="160:200"
  ["ConnectedComponent${delimiter}8"]="160:200"
  ["ConnectedComponent${delimiter}10"]="160:200"
  ["ConnectedComponent${delimiter}16"]="160:200"
  ["ConnectedComponent${delimiter}20"]="160:200"
  ["ConnectedComponent${delimiter}32"]="160:200"
  ["ConnectedComponent${delimiter}40"]="160:200"
  ["ConnectedComponent${delimiter}60"]="160:200"
  ["ConnectedComponent${delimiter}80"]="160:200"
  ["ConnectedComponent${delimiter}100"]="160:200"
  ["ConnectedComponent${delimiter}120"]="160:200"
  ["ConnectedComponent${delimiter}140"]="160:200"
  ["ConnectedComponent${delimiter}160"]="160:200"
)

# Backup original conf.sh
cp conf.sh conf.sh.backup

# Function to display usage message
function usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo
  echo "  -g, --sudo-group                    Specify the sudo group; eg. amperesudo, carvsudo"
  echo "  -m, --master                        Specify the Spark master; eg. ampere."
  echo "  -s, --slave                         Specify the Spark slave; eg. ampere."
  echo "  -e, --execution <execution>         Specify the execution mode; eg. n|native or f|flexheap"
  echo "  -b, --build <jvm variant>           Specify the jvm variant for flexheap; r|release, f|fastdebug"
  echo "  -j, --java <path>                   Specify the java path."
  echo "  -f, --h2-dir <path>                 Specify the path of the directory which contains the h2 backing file, eg. /spare2/perpap/fmap"
  echo "  -p, --shuffle-dir <path>            Specify the path of the directory which contains the spark shuffle directory, eg. /spare2/perpap/spark"
  echo "  -d, --datasets <path>               Specify the path of the directory which contains the spark datasets, eg. /spare2/perpap/datasets"
  echo "  -r, --results <path>                Specify the path of SparkBench's results. eg. /spare/perpap/spark_results"
  echo "  -l, --load-config <path>            Specify the path of a script containing the configurations of each benchmark."
  echo "  -i, --iterations                    Specify the number of iterations for running the benchmarks."
  echo "  -n, --numa                          Use NUMA via -XX:+UseNUMA"
  echo "  -c, --cgroups                       Use cgroups"
  echo "  -h, --help                          Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./run_batch.sh                                            "
  echo "./run_batch.sh -i 3                                       "
  echo "./run_batch.sh -r /spare/s1/perpap/spark_results              "
  echo "./run_batch.sh -r /spare/s1/perpap/spark_results -i 3              "
  echo "./run_batch.sh -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -i 3"
  echo "./run_batch.sh -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -c"
  echo "./run_batch.sh -g amperesudo -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -l asplos_config.sh -c"
  echo "./run_batch.sh -g amperesudo -m ampere -s ampere -b r -f /spare/s0/perpap/fmap -p /spare/s1/perpap/spark -d /spare/s1/perpap/datasets -r /spare/s1/perpap/spark_results -l asplos_config.sh -n -c"
}

function run_benchmarks() {
  sed -i "s|^MY_JAVA_HOME=.*|MY_JAVA_HOME=${JDK_PATH}|" conf.sh
  export MY_JAVA_HOME=$JDK_PATH

  if [[ $EXECUTION == "s" ]]; then
    STORAGE_LEVELS=("MEMORY_AND_DISK")
    sed -i "s|^ENABLE_FLEXHEAP=.*|ENABLE_FLEXHEAP=false|" conf.sh
  else
    STORAGE_LEVELS=("MEMORY_ONLY")
    sed -i "s|^ENABLE_FLEXHEAP=.*|ENABLE_FLEXHEAP=true|" conf.sh
  fi

  # Outer loop - BENCHMARKS
  for BENCHMARK in "${BENCHMARKS[@]}"; do
    sed -i "s/^BENCHMARKS=(.*)/BENCHMARKS=(\"$BENCHMARK\")/" conf.sh
    # Middle loop - STORAGE_LEVELS
    for STORAGE_LEVEL in "${STORAGE_LEVELS[@]}"; do
      sed -i "s/^S_LEVEL=(.*)/S_LEVEL=(\"$STORAGE_LEVEL\")/" conf.sh

      # Inner loop - EXECUTOR_CORES
      for MUTATOR_THREADS in "${EXECUTOR_CORES[@]}"; do
        if [[ $STORAGE_LEVEL == "MEMORY_AND_DISK" && $MUTATOR_THREADS -gt 40 ]]; then
          continue
        fi

        # Construct the key for fetching the configuration
        key="${BENCHMARK}${delimiter}${MUTATOR_THREADS}"
        # Fetch the configuration using the constructed key
        config="${CONFIG_MAP[$key]}"
        # Split the configuration into H1_SIZE and MEM_BUDGET
        IFS=':' read -r H1_SIZE MEM_BUDGET <<<"$config"
        # Update H1_SIZE, MEM_BUDGET, BENCHMARKS and EXEC_CORES in conf.sh
        sed -i "s/^H1_SIZE=(.*)/H1_SIZE=( $H1_SIZE )/" conf.sh
        sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=${MEM_BUDGET}G/" conf.sh
        sed -i "s/^EXEC_CORES=(.*)/EXEC_CORES=($MUTATOR_THREADS)/" conf.sh

        if [[ $MUTATOR_THREADS -le 8 ]]; then
          GC_THREADS=$MUTATOR_THREADS
        else
          # Compute GC_THREADS based on MUTATOR_THREADS using bc, properly rounding to the nearest integer
          GC_THREADS=$(echo "$MUTATOR_THREADS * 5 / 8" | bc -l)
          # Round the result by adding 0.5 and then truncating the decimal part
          GC_THREADS=$(echo "$GC_THREADS + 0.5" | bc)
          # Since bc does not automatically drop the decimal part when scale is not set, explicitly truncate the decimal part
          GC_THREADS=$(echo "$GC_THREADS / 1" | bc)
        fi
        sed -i "s/^GC_THREADS=.*/GC_THREADS=$GC_THREADS/" conf.sh

        # Execute run.sh with conditional flags based on EXECUTION
        ./run.sh -n $ITERATIONS -o $RESULTS_PATH "-$EXECUTION"
      done
    done
  done
  sed -i "s/^USE_CGROUPS=.*/USE_CGROUPS=false/" conf.sh
}

function parse_script_arguments() {
  local OPTIONS=g:m:s:e:b:j:f:p:d:r:l:i:nch
  local LONGOPTIONS=sudo-group:,master:,slave:,execution:,build:,jdk:,h2-dir:,shuffle-dir:,datasets:,results:,load-config:,iterations:,numa,cgroups,help

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
    -g | --sudo-group)
      SUDOGROUP="$2"
      sed -i "s|^SUDOGROUP=.*|SUDOGROUP=${SUDOGROUP}|" conf.sh
      shift 2
      ;;
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
    -e | --execution)
      if [[ "$2" == "f" || "$2" == "flexheap" ]]; then
        EXECUTION="t"
      elif [[ "$2" == "n" || "$2" == "native" ]]; then
        EXECUTION="s"
      else
        echo "Invalid execution mode; Please provide f|flexheap or n|native"
        exit ${ERRORS[INVALID_OPTION]}
      fi
      shift 2
      ;;
    -b | --build)
      JAVA_BUILD="$2"
      if [[ "$2" == "r" || "$2" == "release" ]]; then
        JAVA_BUILD=$TERA_JDK17_AARCH64_RELEASE
      elif [[ "$2" == "f" || "$2" == "fastdebug" ]]; then
        JAVA_BUILD=$TERA_JDK17_AARCH64_FASTDEBUG
      else
        echo "Invalid java build; Please provide r|release or f|fastdebug"
        exit ${ERRORS[INVALID_OPTION]}
      fi
      shift 2
      ;;
    -j | --jdk)
      if [[ -f "$2"/bin/java ]]; then
        JDK_PATH="$2"
      else
        echo "Error: '$JDK_PATH/bin/java' does not exist."
        exit 1
      fi
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
    -r | --results)
      RESULTS_PATH="$2"
      shift 2
      ;;
    -l | --load-config)
      CONFIG_FILE="$2"
      if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"

        # Initialize a local associative array
        declare -A NEW_CONFIG_MAP

        # Load the configuration into a local variable
        local config_string=$(load_config)
        # Parse the configuration string and populate the associative array
        while IFS== read -r key value; do
          NEW_CONFIG_MAP["$key"]="$value"
        done <<<"$config_string"
        # Replace the default CONFIG_MAP with the new configuration
        CONFIG_MAP=()
        for key in "${!NEW_CONFIG_MAP[@]}"; do
          CONFIG_MAP["$key"]="${NEW_CONFIG_MAP[$key]}"
        done
      else
        echo "Error: File '$CONFIG_FILE' does not exist."
        exit 1
      fi
      shift 2
      ;;
    -i | --iterations)
      ITERATIONS="$2"
      validateIterations
      shift 2
      ;;
    -n | --numa)
      sed -i "s/^USE_NUMA=.*/USE_NUMA=true/" conf.sh
      shift
      ;;
    -c | --cgroups)
      sed -i "s/^USE_CGROUPS=.*/USE_CGROUPS=true/" conf.sh
      shift
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

function validateIterations() {
  if [[ ! $ITERATIONS =~ ^[0-9]+$ ]]; then 
    echo "iterations:$ITERATIONS is not an integer."
    exit ${ERRORS[NOT_AN_INTEGER]} 
  elif [[ $ITERATIONS -lt 1 || $ITERATIONS -gt 5 ]]; then                          
    echo "iterations:$ITERATIONS is not within the range 1 to 5."
    exit ${ERRORS[OUT_OF_RANGE]} 
  fi
}

parse_script_arguments "$@"
run_benchmarks

# Restore the original conf.sh to leave no side effects
cp conf.sh.backup conf.sh
rm conf.sh.backup
