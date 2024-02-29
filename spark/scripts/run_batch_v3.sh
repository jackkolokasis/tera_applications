#!/usr/bin/env bash

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

# Define a "delimiter" to simulate multidimensional associative arrays
delimiter=":"

# Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}8"]="4:8|64:80"
: '
    ["LinearRegression${delimiter}8"]="4:8|12:20|20:36|36:56|64:80|68:84|84:100"
    ["LinearRegression${delimiter}20"]="80:100|96:120|112:140|128:160"
    ["LinearRegression${delimiter}40"]="120:148|136:168|152:188|168:208"
    ["LinearRegression${delimiter}60"]="140:172|156:192|172:212|188:232|204:252"
    ["LinearRegression${delimiter}80"]="176:212|192:232|208:254"
    ["LinearRegression${delimiter}100"]="200:256"
    #["LinearRegression${delimiter}160"]="200:256" #OOM
    ["LogisticRegression${delimiter}8"]="64:80|68:84|84:100"
    ["LogisticRegression${delimiter}20"]="80:100|96:120|112:140|128:160"
    ["LogisticRegression${delimiter}40"]="120:148|136:168|152:188|168:208"
    ["LogisticRegression${delimiter}60"]="140:172|156:192|172:212|188:232|204:252"
    ["LogisticRegression${delimiter}80"]="176:212|192:232|208:254"
    ["LogisticRegression${delimiter}100"]="200:256"
    #["LogisticRegression${delimiter}160"]="200:256"
    ["PageRank${delimiter}8"]="64:80|68:84|84:100"
    ["PageRank${delimiter}20"]="80:100|96:120|112:140|128:160"
    ["PageRank${delimiter}40"]="120:148|136:168|152:188|168:208"
    ["PageRank${delimiter}60"]="140:172|156:192|172:212|188:232|204:252"
    ["PageRank${delimiter}80"]="176:212|192:232|208:254"
    ["PageRank${delimiter}100"]="200:256"
    #["PageRank${delimiter}160"]="200:256"
    ["ConnectedComponent${delimiter}8"]="68:84|84:100"
    ["ConnectedComponent${delimiter}20"]="80:100|96:120|112:140|128:160"
    ["ConnectedComponent${delimiter}40"]="120:148|136:168|152:188|168:208"
    ["ConnectedComponent${delimiter}60"]="140:172|156:192|172:212|188:232|204:252"
    ["ConnectedComponent${delimiter}80"]="176:212|192:232|208:254"
    ["ConnectedComponent${delimiter}100"]="200:256"
    #["ConnectedComponent${delimiter}160"]="200:256"
'
)

BENCHMARKS=(LinearRegression LogisticRegression PageRank ConnectedComponent)
#BENCHMARKS=(ConnectedComponent)
EXECUTOR_CORES=(8 20 40 60 80 100)
#STORAGE_LEVELS=("MEMORY_ONLY" "MEMORY_AND_DISK")
STORAGE_LEVELS=("MEMORY_AND_DISK")
RESULTS_PATH="/spare/perpap/spark_results"
ITERATIONS=1

# Backup original conf.sh
cp conf.sh conf.sh.backup

# Function to display usage message
function usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo
  echo "  -o, --output <path>      	                        Specify the path of SparkBench's results. eg. /spare/perpap/spark_results"
  echo "  -i, --iterations                                      Specify the number of iterations for running the benchmarks."
  echo "  -h, --help                                            Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./run_batch.sh                 			 	Run 1 iterations of each benchmark and save the results in a default directory."
  echo "./run_batch.sh -i 3            			 	Run 3 iterations of each benchmark and save the results in a default directory."
  echo "./run_batch.sh -o /spare/perpap/spark_results    	Run 1 iterations of each benchmark and save the results in /spare/perpap/spark_results"
  echo "./run_batch.sh -o /spare/perpap/spark_results -i 3	Run 3 iterations of each benchmark and save the results in /spare/perpap/spark_results."
}

function checkForOutOfMemory() {
  local filePattern="$1" # The file path pattern is the first argument to the function
  local found=0 # Flag to indicate if "OutOfMemory" has been found

  # Expand the wildcard in the file path and loop through each matching file
  for file in $filePattern; do
    # Check if the file exists and is a regular file
    if [ -f "$file" ]; then
      # Use grep to search for "OutOfMemory" in the file
      if grep -q "OutOfMemory" "$file"; then
        echo "OutOfMemory found in $file"
        found=1
        break # Exit the loop early if "OutOfMemory" is found
      fi
    fi
  done

  return $found # Return the result
}

function launchBenchmarks(){
# Outer loop - BENCHMARKS
  for BENCHMARK in "${BENCHMARKS[@]}"; do
      sed -i "s/^BENCHMARKS=(.*)/BENCHMARKS=(\"$BENCHMARK\")/" conf.sh
      # Middle loop - STORAGE_LEVELS
      for STORAGE_LEVEL in "${STORAGE_LEVELS[@]}"; do
	  sed -i "s/^S_LEVEL=(.*)/S_LEVEL=(\"$STORAGE_LEVEL\")/" conf.sh
	  # Inner loop - EXECUTOR_CORES
	  for MUTATOR_THREADS in "${EXECUTOR_CORES[@]}"; do
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

              # Construct the key for fetching the configuration
              key="${BENCHMARK}${delimiter}${MUTATOR_THREADS}"
              # Fetch the configuration using the constructed key
              config_values="${CONFIG_MAP[$key]}"
              # New loop to handle multiple configurations
              IFS='|' read -ra ADDR <<< "$config_values"
              for config in "${ADDR[@]}"; do
                # Split config into H1_SIZE and MEM_BUDGET
                IFS=':' read h1_size mem_budget <<< "$config"
                # Update conf.sh with the current H1_SIZE and MEM_BUDGET
                sed -i "s/H1_SIZE=(.*)/H1_SIZE=($h1_size)/" conf.sh
                sed -i "s/MEM_BUDGET=.*/MEM_BUDGET=$mem_budget/" conf.sh
                # Execute run.sh with conditional flags based on STORAGE_LEVEL
                if [ $STORAGE_LEVEL == "MEMORY_ONLY" ]; then
                   echo "[TERAHEAP]Execution of $BENCHMARK using $MUTATOR_THREADS mutator threads and $GC_THREADS GC threads."
                   ./run.sh -n $ITERATIONS -o $RESULTS_PATH -t
                   if checkForOutOfMemory "$RESULTS_PATH/FLEXHEAP/$BENCHMARK/*/run0/conf0/tmp_out.txt"; then
                      echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Successful configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget"
                      break # Exit the loop if successful
                   else
                      echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Trying next configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget failed"
                   fi
                else
                   echo "[NATIVE]Execution of $BENCHMARK using $MUTATOR_THREADS mutator threads and $GC_THREADS GC threads."
                   ./run.sh -n $ITERATIONS -o $RESULTS_PATH -s
                   if checkForOutOfMemory "$RESULTS_PATH/NATIVE/$BENCHMARK/*/run0/conf0/tmp_out.txt"; then
                      echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Trying next configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget failed"
                   else 
                      echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Successful configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget"
                      break # Exit the loop if successful
                   fi
                fi
                : '
                # Check if run.sh succeeded
                if [ $? -eq 0 ]; then
                    echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Successful configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget"
                    break # Exit the loop if successful
                else
                    echo "${BENCHMARK} with MUTATOR_THREADS=$MUTATOR_THREADS, GC_THREADS=$GC_THREADS. Trying next configuration: H1_SIZE=$h1_size and MEM_BUDGET=$mem_budget failed"
                fi
                '
              done
	  done
      done
   done
}

function processArgs(){
  local OPTIONS=o:i:h
  local LONGOPTIONS=output:,iterations:,help

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
	-o|--output)
           RESULTS_PATH="$2"
           shift 2
           ;;
        -i|--iterations)
           ITERATIONS="$2"
           validateIterations
           shift 2
           ;;
        -h|--help)
           usage
           exit 0
           ;;
        --)
           shift
           break
           ;;
         *)
           echo "Programming error"
           return ${ERRORS[PROGRAMMING_ERROR]} 2>/dev/null || exit ${ERRORS[PROGRAMMING_ERROR]}  # This will return if sourced, and exit if run as a standalone script
         ;;
    esac
  done
}

validateIterations() {
  if [[ ! $ITERATIONS =~ ^[0-9]+$ ]]; then # Validate if iterations is an integer
     echo "iterations:$ITERATIONS is not an integer."
     return ${ERRORS[NOT_AN_INTEGER]} 2>/dev/null || exit ${ERRORS[NOT_AN_INTEGER]}  # This will return if sourced, and exit if run as a standalone script
  elif [[ $ITERATIONS -lt 1 || $ITERATIONS -gt 5 ]]; then # Check if the iterations is within the range 1 to 5
     echo "iterations:$ITERATIONS is not within the range 1 to 5."
     return ${ERRORS[OUT_OF_RANGE]} 2>/dev/null || exit ${ERRORS[OUT_OF_RANGE]}  # This will return if sourced, and exit if run as a standalone script
  fi
}

processArgs "$@"
launchBenchmarks

# Restore the original conf.sh to leave no side effects
cp conf.sh.backup conf.sh
rm conf.sh.backup

