#!/usr/bin/env bash
BENCHMARKS=("ConnectedComponent" "PageRank" "LinearRegression" "LogisticRegression")
#BENCHMARKS=("LinearRegression")
#BENCHMARKS=("ConnectedComponent" "PageRank")
#BENCHMARKS=("PageRank")
#BENCHMARKS=("ConnectedComponent")

#EXECUTOR_CORES=(16 8 4)
EXECUTOR_CORES=(8)

#EXECUTOR_CORES=(160 80 40)
#EXECUTOR_CORES=(20 10)

function load_config() {
  local delimiter=":"
  # Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
  
  declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}4"]="54:70"
    ["LinearRegression${delimiter}8"]="54:70"
    ["LinearRegression${delimiter}16"]="54:70" 
#    ["LinearRegression${delimiter}16"]="54:70"   # NATIVE OOM
    ["LogisticRegression${delimiter}4"]="54:70"
    ["LogisticRegression${delimiter}8"]="54:70"
    ["LogisticRegression${delimiter}16"]="54:70"
#    ["LogisticRegression${delimiter}16"]="54:70"  # NATIVE OOM
    ["PageRank${delimiter}4"]="64:80"
    ["PageRank${delimiter}8"]="64:80"
    ["PageRank${delimiter}16"]="64:80"
    ["ConnectedComponent${delimiter}4"]="68:84"
    ["ConnectedComponent${delimiter}8"]="68:84"
    ["ConnectedComponent${delimiter}16"]="68:84"
  )
  :'
  declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}4"]="27:43"
    ["LinearRegression${delimiter}8"]="27:43"
    ["LinearRegression${delimiter}16"]="27:43" 
#    ["LinearRegression${delimiter}16"]="54:70"   # NATIVE OOM
    ["LogisticRegression${delimiter}4"]="27:43"
    ["LogisticRegression${delimiter}8"]="27:43"
    ["LogisticRegression${delimiter}16"]="27:43"
#    ["LogisticRegression${delimiter}16"]="54:70"  # NATIVE OOM
    ["PageRank${delimiter}4"]="16:32"
    ["PageRank${delimiter}8"]="16:32"
    ["PageRank${delimiter}16"]="16:32"
    ["ConnectedComponent${delimiter}4"]="17:33"
    ["ConnectedComponent${delimiter}8"]="17:33"
    ["ConnectedComponent${delimiter}16"]="17:33"
  )
  '
  # Print the associative array in key:value format
  for key in "${!CONFIG_MAP[@]}"; do
    echo "$key=${CONFIG_MAP[$key]}"
  done
}
