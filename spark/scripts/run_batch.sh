#!/usr/bin/env bash

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

# Define mappings for H1_SIZE and MEM_BUDGET for each benchmark
declare -A H1_SIZE_MAP=(
    [LinearRegression]=68
    [LogisticRegression]=68
    [PageRank]=68
    [ConnectedComponent]=68
)

declare -A MEM_BUDGET_MAP=(
    [LinearRegression]=84
    [LogisticRegression]=84
    [PageRank]=84
    [ConnectedComponent]=84
)

BENCHMARKS=(LinearRegression LogisticRegression PageRank ConnectedComponent)
STORAGE_LEVELS=("MEMORY_ONLY" "MEMORY_AND_DISK")
EXECUTOR_CORES=(8 40 80 160)
RESULTS_PATH="/spare/perpap/spark_results"
ITERATIONS=1

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

# Backup original conf.sh
cp conf.sh conf.sh.backup

function launchBenchmarks(){
    # Outer loop - BENCHMARKS
	for BENCHMARK in "${BENCHMARKS[@]}"; do
	    # Retrieve the H1_SIZE and MEM_BUDGET for the current benchmark
	    local H1_SIZE=${H1_SIZE_MAP[$BENCHMARK]}
	    local MEM_BUDGET=${MEM_BUDGET_MAP[$BENCHMARK]}G  # Append 'G' assuming MEM_BUDGET is specified in Gigabytes
	    # Update H1_SIZE and MEM_BUDGET in conf.sh
	    sed -i "s/^H1_SIZE=(.*)/H1_SIZE=( $H1_SIZE )/" conf.sh
	    sed -i "s/^MEM_BUDGET=.*/MEM_BUDGET=${MEM_BUDGET}/" conf.sh
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
	            # Execute run.sh with conditional flags based on STORAGE_LEVEL
	            if [ $STORAGE_LEVEL == "MEMORY_ONLY" ]; then
	                echo "[TERAHEAP]Execution of $BENCHMARK using $MUTATOR_THREADS mutator threads and $GC_THREADS GC threads."
	                ./run.sh -n $ITERATIONS -o $RESULTS_PATH -t
	            else
	                echo "[NATIVE]Execution of $BENCHMARK using $MUTATOR_THREADS mutator threads and $GC_THREADS GC threads."
	                ./run.sh -n $ITERATIONS -o $RESULTS_PATH -s
	            fi
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
                return 0 2>/dev/null || exit 0  # This will return if sourced, and exit if run as a standalone script
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

# Restore the original conf.sh
cp conf.sh.backup conf.sh
rm conf.sh.backup


