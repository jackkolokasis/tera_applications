#!/usr/bin/env bash
BENCHMARKS=("ConnectedComponent" "PageRank" "LinearRegression" "LogisticRegression")
#BENCHMARKS=("PageRank" "LinearRegression" "LogisticRegression")
#BENCHMARKS=("LinearRegression" "LogisticRegression")
#BENCHMARKS=("LinearRegression")
#BENCHMARKS=("LogisticRegression")
#BENCHMARKS=("ConnectedComponent" "PageRank")
#BENCHMARKS=("PageRank")
#BENCHMARKS=("ConnectedComponent")

EXECUTOR_CORES=(8)
#EXECUTOR_CORES=(16)
#EXECUTOR_CORES=(32)
#EXECUTOR_CORES=(128 64 32 16 8)
#EXECUTOR_CORES=(128)
#EXECUTOR_CORES=(160)
NUM_EXECUTORS=(1)
#NUM_EXECUTORS=(1)
function load_config() {
  local delimiter=":"
  # Define mappings for H1_SIZE and MEM_BUDGET for each benchmark and EXEC_CORES
  # ParallelScavenge  

  
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

  : '
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
    ["PageRank${delimiter}8"]="112:132"
    ["PageRank${delimiter}16"]="112:132"
    ["PageRank${delimiter}32"]="112:132"
    ["PageRank${delimiter}64"]="64:80"
    ["PageRank${delimiter}128"]="64:80"
    ["PageRank${delimiter}160"]="64:80"
    ["ConnectedComponent${delimiter}4"]="68:84"
    ["ConnectedComponent${delimiter}8"]="112:132"
    ["ConnectedComponent${delimiter}16"]="112:132"
    ["ConnectedComponent${delimiter}32"]="112:132"
    ["ConnectedComponent${delimiter}64"]="68:84"
    ["ConnectedComponent${delimiter}128"]="68:84"
    ["ConnectedComponent${delimiter}160"]="68:84"
  )
  '
: '
declare -A CONFIG_MAP=(
    
    #["LinearRegression${delimiter}1"]="192:176"
    #["LinearRegression${delimiter}1"]="8:192"
    #["LinearRegression${delimiter}1"]="16:192" 
    #["LinearRegression${delimiter}1"]="32:192"
    #["LinearRegression${delimiter}64"]="192:208"
    #["LinearRegression${delimiter}128"]="192:208"
    #["LinearRegression${delimiter}1"]="64:224"
    #["LinearRegression${delimiter}1"]="64:192"
    #["LinearRegression${delimiter}1"]="128:128"
    #["LinearRegression${delimiter}1"]="128:160"
    #["LinearRegression${delimiter}1"]="128:192"
    #["LinearRegression${delimiter}1"]="128:96"
    ["LinearRegression${delimiter}8"]="54"
    ["LinearRegression${delimiter}16"]="54"
    ["LinearRegression${delimiter}32"]="54"
    ["LinearRegression${delimiter}64"]="54"
    #["LinearRegression${delimiter}1"]="8:54"
    #["LinearRegression${delimiter}1"]="16:54"
    #["LinearRegression${delimiter}1"]="32:54"
    #["LinearRegression${delimiter}1"]="64:54"
    #["LinearRegression${delimiter}1"]="128:54"
    #["LinearRegression${delimiter}1"]="160:54"
    #["LinearRegression${delimiter}1"]="160:224"
    #["LinearRegression${delimiter}1"]="160:192"
    #["LogisticRegression${delimiter}4"]="160:176"
    #["LogisticRegression${delimiter}1"]="8:192"
    #["LogisticRegression${delimiter}1"]="16:192"
    #["LogisticRegression${delimiter}1"]="32:192"
    #["LogisticRegression${delimiter}64"]="192:208"
    #["LogisticRegression${delimiter}128"]="192:208"
    #["LogisticRegression${delimiter}1"]="64:224"
    #["LogisticRegression${delimiter}1"]="64:192"
    #["LogisticRegression${delimiter}1"]="128:128"
    #["LogisticRegression${delimiter}1"]="128:160"
    #["LogisticRegression${delimiter}1"]="128:192"
    #["LogisticRegression${delimiter}1"]="128:96"
    ["LogisticRegression${delimiter}1"]="8:54"
    ["LogisticRegression${delimiter}1"]="16:54"
    ["LogisticRegression${delimiter}1"]="32:54"
    ["LogisticRegression${delimiter}1"]="64:54"
    #["LogisticRegression${delimiter}1"]="128:54"
    #["LogisticRegression${delimiter}1"]="160:54"
    #["LogisticRegression${delimiter}1"]="160:192"
    #["LogisticRegression${delimiter}1"]="160:224"
    #["PageRank${delimiter}4"]="176:192"
    #["PageRank${delimiter}1"]="8:192"
    #["PageRank${delimiter}1"]="16:192"
    #["PageRank${delimiter}1"]="32:192"
    #["PageRank${delimiter}64"]="200:216"
    #["PageRank${delimiter}128"]="200:216"
    #["PageRank${delimiter}1"]="64:224"
    #["PageRank${delimiter}1"]="64:192"
    #["PageRank${delimiter}1"]="128:128"
    #["PageRank${delimiter}1"]="128:160"
    #["PageRank${delimiter}1"]="128:192"
    #["PageRank${delimiter}1"]="128:112"
    ["PageRank${delimiter}1"]="8:64"
    ["PageRank${delimiter}1"]="16:64"
    ["PageRank${delimiter}1"]="32:64"
    ["PageRank${delimiter}1"]="64:64"
    #["PageRank${delimiter}1"]="128:64"
    #["PageRank${delimiter}1"]="160:64"
    #["PageRank${delimiter}1"]="160:192"
    #["PageRank${delimiter}1"]="160:224"
#    ["ConnectedComponent${delimiter}1"]="68:84"
    #["ConnectedComponent${delimiter}4"]="180:196"
    #["ConnectedComponent${delimiter}1"]="8:192"
    #["ConnectedComponent${delimiter}1"]="16:192"
    #["ConnectedComponent${delimiter}1"]="32:192"
    #["ConnectedComponent${delimiter}64"]="200:216"
    #["ConnectedComponent${delimiter}128"]="20:216"
    #["ConnectedComponent${delimiter}1"]="64:224"
    #["ConnectedComponent${delimiter}1"]="64:192"
    #["ConnectedComponent${delimiter}1"]="128:128"
    #["ConnectedComponent${delimiter}1"]="128:160"
    #["ConnectedComponent${delimiter}1"]="128:192" 
    #["ConnectedComponent${delimiter}1"]="128:116"
    ["ConnectedComponent${delimiter}1"]="8:68"
    ["ConnectedComponent${delimiter}1"]="16:68"
    ["ConnectedComponent${delimiter}1"]="32:68"
    ["ConnectedComponent${delimiter}1"]="64:68"
    #["ConnectedComponent${delimiter}1"]="128:68"
    #["ConnectedComponent${delimiter}1"]="160:68"
    #["ConnectedComponent${delimiter}1"]="160:192"
    #["ConnectedComponent${delimiter}1"]="160:224" 
)
'
  # Print the associative array in key:value format
  for key in "${!CONFIG_MAP[@]}"; do
    echo "$key=${CONFIG_MAP[$key]}"
  done
}
