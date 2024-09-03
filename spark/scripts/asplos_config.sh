#!/usr/bin/env bash
BENCHMARKS=("ConnectedComponent" "PageRank" "LinearRegression" "LogisticRegression")

# Define EXECUTOR_CORES to override the default value in run_batch_v2.sh
EXECUTOR_CORES=(16 8 4)
function load_config() {
  local delimiter=":"
  # Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
  declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}4"]="54:70"
    ["LinearRegression${delimiter}8"]="54:70"
    ["LinearRegression${delimiter}16"]="54:70"
    ["LogisticRegression${delimiter}4"]="54:70"
    ["LogisticRegression${delimiter}8"]="54:70"
    ["LogisticRegression${delimiter}16"]="54:70"
    ["PageRank${delimiter}4"]="64:80"
    ["PageRank${delimiter}8"]="64:80"
    ["PageRank${delimiter}16"]="64:80"
    ["ConnectedComponent${delimiter}4"]="68:84"
    ["ConnectedComponent${delimiter}8"]="68:84"
    ["ConnectedComponent${delimiter}16"]="68:84"
  )
  # Print the associative array in key:value format
  for key in "${!CONFIG_MAP[@]}"; do
    echo "$key=${CONFIG_MAP[$key]}"
  done
}
