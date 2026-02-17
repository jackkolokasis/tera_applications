#!/usr/bin/env bash
BENCHMARKS=("ConnectedComponent" "PageRank" "LinearRegression" "LogisticRegression")
EXECUTOR_CORES=(128 64 32 16 8)
NUM_EXECUTORS=(1)
function load_config() {
  local delimiter=":"
  # mappings [benchmark, mutators]->[H1_SIZE, MEM_BUDGET]
  declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}4"]="54:70"
    ["LinearRegression${delimiter}8"]="54:70"
    ["LinearRegression${delimiter}16"]="54:70" 
    ["LinearRegression${delimiter}32"]="54:70"
    ["LinearRegression${delimiter}64"]="54:70"
    ["LinearRegression${delimiter}128"]="54:70"
    ["LinearRegression${delimiter}160"]="54:70"
    ["LogisticRegression${delimiter}4"]="54:70"
    ["LogisticRegression${delimiter}8"]="54:70"
    ["LogisticRegression${delimiter}16"]="54:70"
    ["LogisticRegression${delimiter}32"]="54:70"
    ["LogisticRegression${delimiter}64"]="54:70"
    ["LogisticRegression${delimiter}128"]="54:70"
    ["LogisticRegression${delimiter}160"]="54:70"
    ["PageRank${delimiter}4"]="64:80"
    ["PageRank${delimiter}8"]="64:80"
    ["PageRank${delimiter}16"]="64:80"
    ["PageRank${delimiter}32"]="64:80"
    ["PageRank${delimiter}64"]="64:80"
    ["PageRank${delimiter}128"]="64:80"
    ["PageRank${delimiter}160"]="64:80"
    ["ConnectedComponent${delimiter}4"]="68:84"
    ["ConnectedComponent${delimiter}8"]="68:84"
    ["ConnectedComponent${delimiter}16"]="68:84"
    ["ConnectedComponent${delimiter}32"]="68:84"
    ["ConnectedComponent${delimiter}64"]="68:84"
    ["ConnectedComponent${delimiter}128"]="68:84"
    ["ConnectedComponent${delimiter}160"]="68:84"
  )

  # Print the associative array in key:value format
  for key in "${!CONFIG_MAP[@]}"; do
    echo "$key=${CONFIG_MAP[$key]}"
  done
}
