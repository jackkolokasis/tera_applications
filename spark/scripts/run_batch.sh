#!/usr/bin/env bash

#set -x
. ./conf.sh
# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

EXECUTOR_CORES=(80 40 20 10)
STORAGE_LEVELS=("MEMORY_ONLY")
RESULTS_PATH=
DATASETS_MOUNT_POINT=
H2_MOUNT_POINT=
SHUFFLE_MOUNT_POINT=
ITERATIONS=1
CONFIG_FILE=
MASTER=
SLAVE=
EXECUTION="t" #t|teraheap f|flexheap n|native
TERAHEAP_HOME=
JDK_PATH=
PROFILER=false
# Define a "delimiter" to simulate multidimensional associative arrays
delimiter=":"

# Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
# ["BENCHMARK:NUTATORS"]="[H1_SIZE:MEM_BUDGET]"

declare -A CONFIG_MAP=()

# Function to display usage message
function usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo
  echo "  -t, --teraheap-home <path>          Specify the TeraHeap home directory."
  echo "  -g, --sudo-group                    Specify the sudo group; eg. amperesudo, carvsudo"
  echo "  -m, --master                        Specify the Spark master; eg. ampere."
  echo "  -s, --slave                         Specify the Spark slave; eg. ampere."
  echo "  -e, --execution <execution>         Specify the execution mode; eg. teraheap_g1|teraheap_ps or native_g1|native_ps "
  echo "  -j, --java <path>                   Specify the java path; eg /spare/s0/perpap/mel/teraheap/jdk17/build/linux-aarch64-server-release/jdk."
  echo "  -f, --h2-dir <path>                 Specify the path of the directory which contains the h2 backing file, eg. /spare/s2/perpap/fmap"
  echo "  -p, --shuffle-dir <path>            Specify the path of the directory which contains the spark shuffle directory, eg. /spare/s2/perpap/spark"
  echo "  -d, --datasets <path>               Specify the path of the directory which contains the spark datasets, eg. /spare/s1/perpap/datasets_256"
  echo "  -r, --results <path>                Specify the path of SparkBench's results. eg. /spare/s2/perpap/spark_results"
  echo "  -l, --load-config <path>            Specify the path of a script containing the configurations of each benchmark."
  echo "  -i, --iterations                    Specify the number of iterations for running the benchmarks."
  echo "  -w, --write-to-t2-policy <policy>   The available policies are: 'AsyncWritePolicy', 'SyncWritePolicy', 'FmapWritePolicy', 'DefaultWritePolicy'"
  echo "  -n, --numa                          Use NUMA via -XX:+UseNUMA"
  echo "  -c, --cgroups                       Use cgroups"
  echo "  -o, --profiler                      Use profiler"
  echo "  -h, --help                          Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./run_batch.sh -g amperesudo -m ampere -s ampere -f /spare/s2/perpap/fmap -p /spare/s2/perpap/spark -t 256 -d /spare/s1/perpap/datasets_256 -r /spare/s2/perpap/spark_results -e teraheap_g1 -j /spare/s0/perpap/mel/teraheap/jdk17/build/linux-aarch64-server-release/jdk -l /spare/s1/perpap/tera_applications/spark/scripts/asplos_config.sh -c"
}

function run_benchmarks() {
  sed -i "s|^TERAHEAP_HOME=.*|TERAHEAP_HOME=${TERAHEAP_HOME}|" conf.sh
  export TERAHEAP_HOME=$TERAHEAP_HOME
  sed -i "s|^MY_JAVA_HOME=.*|MY_JAVA_HOME=${JDK_PATH}|" conf.sh
  export MY_JAVA_HOME=$JDK_PATH

  if [[ $EXECUTION == "s" ]]; then
    STORAGE_LEVELS=("MEMORY_AND_DISK")
  else
    STORAGE_LEVELS=("MEMORY_ONLY")
  fi

  # Outer loop - BENCHMARKS
  for BENCHMARK in "${BENCHMARKS[@]}"; do
    sed -i "s/^BENCHMARKS=(.*)/BENCHMARKS=(\"$BENCHMARK\")/" conf.sh
    echo "BENCHMARK:$BENCHMARK"
    cd "./configs/workloads/${DATA_SIZE}/${BENCHMARK}/" || exit
    sed -i '/NUM_OF_PARTITIONS/c\NUM_OF_PARTITIONS='"$NUM_OF_PARTITIONS" env.sh
    sed -i '/SPARK_STORAGE_MEMORYFRACTION/c\SPARK_STORAGE_MEMORYFRACTION='"$MEM_FRACTION" env.sh
    cd - >/dev/null || exit

    if [[ $BENCHMARK == "PageRank" || $BENCHMARK == "ConnectedComponent" ]]; then
        sed -i 's/^H1_MEM_REGION_SIZE=.*/H1_MEM_REGION_SIZE=16/' conf.sh
    elif [[ $BENCHMARK == "LinearRegression" || $BENCHMARK == "LogisticRegression" ]]; then
	sed -i 's/^H1_MEM_REGION_SIZE=.*/H1_MEM_REGION_SIZE=8/' conf.sh
    fi   
 
    # Middle loop - STORAGE_LEVELS
    for STORAGE_LEVEL in "${STORAGE_LEVELS[@]}"; do
      sed -i "s/^S_LEVEL=(.*)/S_LEVEL=(\"$STORAGE_LEVEL\")/" conf.sh
              # Inner loop - EXECUTOR_CORES
	      
	      for MUTATOR_THREADS in "${EXECUTOR_CORES[@]}"; do
		cd "$DISABLE_CORES_DIR" || exit
		sudo ./disable_cpus.sh -f 1 -e
		sudo ./disable_cpus.sh -f $MUTATOR_THREADS -d
		cd - >/dev/null || exit
		
		if [[ $STORAGE_LEVEL == "MEMORY_AND_DISK" && $MUTATOR_THREADS -gt 8 ]]; then
		  continue
		fi
  
		# Construct the key for fetching the configuration
		key="${BENCHMARK}${delimiter}${MUTATOR_THREADS}"
                #key="${BENCHMARK}${delimiter}${EXECUTORS}"
		# Fetch the configuration using the constructed key
		config="${CONFIG_MAP[$key]}"
		# Split the configuration into H1_SIZE and MEM_BUDGET
		#IFS=':' read -r H1_SIZE MEM_BUDGET <<<"$config"
		IFS=":" read -r H1_SIZE MEM_BUDGET NUM_OF_PARTITIONS <<<"$config"
                # Update H1_SIZE, MEM_BUDGET, MEM_OVERHEAD, EXEC_CORES in conf.sh
		#sed -i "s/^H1_SIZE=(.*)/H1_SIZE=( $H1_SIZE )/" conf.sh
		#sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=${MEM_BUDGET}G/" conf.sh
		#sed -i "s/^EXEC_CORES=(.*)/EXEC_CORES=($MUTATOR_THREADS)/" conf.sh

                # compute overhead in GB
                MEM_OVERHEAD=$(( ${MEM_BUDGET%G} - H1_SIZE ))
                sed -i "s/^H1_SIZE=(.*)/H1_SIZE=($H1_SIZE)/" conf.sh
		sed -i -E "s/^MEM_BUDGET=.*/MEM_BUDGET=${MEM_BUDGET}G/" conf.sh
                sed -i -E "s/^MEM_OVERHEAD=.*/MEM_OVERHEAD=${MEM_OVERHEAD}/" conf.sh
                sed -i "s/^EXEC_CORES=(.*)/EXEC_CORES=($MUTATOR_THREADS)/" conf.sh
                sed -i -E "s/^NUM_OF_PARTITIONS=.*/NUM_OF_PARTITIONS=${NUM_OF_PARTITIONS}/" conf.sh
                sed -i "s|^MNT_BENCHMARK_DATASETS=.*|MNT_BENCHMARK_DATASETS=${DATASETS_MOUNT_POINT}_${NUM_OF_PARTITIONS}|" conf.sh
	        
                # per-executor "soft" budget in GB (heap + overhead)
                #PER_EXEC_BUDGET="$(( H1_SIZE + MEM_OVERHEAD ))"
	        #MEM_BUDGET="$(( EXECUTORS * PER_EXEC_BUDGET ))"
	        #sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=${MEM_BUDGET}G/" conf.sh

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
		if [[ $PROFILER == "true" ]]; then
		    ./run.sh -i $ITERATIONS -o $RESULTS_PATH -e $EXECUTION "-f"
	        else
		    ./run.sh -i $ITERATIONS -o $RESULTS_PATH -e $EXECUTION	
		fi
	      done
      #done
    done
  done
  sed -i "s/^USE_CGROUPS=.*/USE_CGROUPS=false/" conf.sh
  
  cd "$DISABLE_CORES_DIR" || exit
  sudo ./disable_cpus.sh -f 1 -e
  cd - >/dev/null || exit
}

function parse_script_arguments() {
  local OPTIONS=g:m:s:e:j:f:p:t:d:r:l:i:w:ncoh
  local LONGOPTIONS=sudo-group:,master:,slave:,execution:,jdk:,h2-dir:,shuffle-dir:,tasks:,datasets:,results:,load-config:,iterations:,write-to-h2-policy:,numa,cgroups,profiler,help

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
        EXECUTION="f"
        sed -i "s/^ENABLE_FLEXHEAP=.*/ENABLE_FLEXHEAP=true/" conf.sh
      elif [[ "$2" == "teraheap_g1" || "$2" == "teraheap_ps" ]]; then
	#sed -i "s/^GC=.*/GC="$2"/" conf.sh 
	sed -i "s|^GC=.*|GC=$2|" conf.sh
	EXECUTION="t"
	sed -i "s/^ENABLE_FLEXHEAP=.*/ENABLE_FLEXHEAP=false/" conf.sh
      elif [[ "$2" == "native_g1" || "$2" == "native_ps" ]]; then
	#sed -i "s/^GC=.*|GC="$2"/" conf.sh 
	sed -i "s|^GC=.*|GC=$2|" conf.sh
	EXECUTION="s"
        sed -i "s/^ENABLE_FLEXHEAP=.*/ENABLE_FLEXHEAP=false/" conf.sh
      else
        echo "Invalid execution mode; Please provide: [f|flexheap] | [teraheap_g1|teraheap_ps] [native_g1]"
        exit ${ERRORS[INVALID_OPTION]}
      fi
      shift 2
      ;;
    -j | --jdk)
      # Only initialize if bin/java exists and is executable
      if [ -x "$2/bin/java" ]; then
	 JDK_PATH="$2"
	 # Strip everything from the first "/jdk..." onward → leaves ".../teraheap"
	 TERAHEAP_HOME="${JDK_PATH%%/jdk*}"
	 echo "JDK_PATH=$JDK_PATH"
	 echo "TERAHEAP_HOME=$TERAHEAP_HOME"
	 sed -i "s|^TERAHEAP_HOME=.*|TERAHEAP_HOME=${TERAHEAP_HOME}|" conf.sh
         #export TERAHEAP_HOME=$TERAHEAP_HOME
         sed -i "s|^MY_JAVA_HOME=.*|MY_JAVA_HOME=${JDK_PATH}|" conf.sh
         #export MY_JAVA_HOME=$JDK_PATH
      else
	 echo "bin/java not found under '$2' – not setting JDK_PATH/TERAHEAP_HOME" >&2
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
    -t | --tasks)
      sed -i "s|^NUM_OF_PARTITIONS=.*|NUM_OF_PARTITIONS=$2/" conf.sh
      shift 2
      ;;
    -d | --datasets)
      DATASETS_MOUNT_POINT="$2"
      # Find the device name using df and process it to remove the /dev/ prefix
      #DEVICE_NAME=$(df "$DATASETS_MOUNT_POINT" | awk 'NR==2 {print $1}' | sed 's|/dev/||')
      # Update the conf.sh script with the device name for DEV_BENCHMARK_DATASETS
      #sed -i "s|^DEV_BENCHMARK_DATASETS=.*|DEV_BENCHMARK_DATASETS=${DEVICE_NAME}|" conf.sh
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
	echo "config_string:$config_string"
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
    -w | --write-to-h2-policy)
      WRITE_POLICY="$2"
      sed -i "s/^TERAHEAP_WRITE_POLICY=.*/TERAHEAP_WRITE_POLICY=${WRITE_POLICY}/" conf.sh
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
    -o | --profiler)
      PROFILER=true
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

