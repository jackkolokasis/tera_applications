#!/usr/bin/env bash
BENCHMARKS=("PageRank" "ConnectedComponent" "LogisticRegression" "LinearRegression")
EXECUTOR_CORES=(160 128 64 32 16 8)
NUM_EXECUTORS=(1)

# Auto partitioning per benchmark (no mode flag needed):
# - PageRank, ConnectedComponent: scaled with cores to reduce overhead at low cores
# - LogisticRegression, LinearRegression: fixed 1024 (safer for large datasets)
function get_partitions() {
  local bench="$1"
  local cores="$2"

  case "$bench" in
    PageRank)
      case "$cores" in
         8)      echo 360 ;;   # keep partitions moderate to reduce overhead
	16)      echo 352 ;;
	32)      echo 352 ;;
        64)      echo 320 ;;
        128|160) echo 256 ;;   # back to 1024 at high cores (stable baseline)
        *)       echo 1024 ;;  # safe fallback for unexpected core counts
      esac
      ;;
    ConnectedComponent)
      case "$cores" in
         8)      echo 328 ;;   # keep partitions moderate to reduce overhead
	16|32|64)echo 320 ;;
        128|160) echo 256 ;;   # back to 1024 at high cores (stable baseline)
        *)       echo 1024 ;;  # safe fallback for unexpected core counts
      esac
      ;;
    LinearRegression)
      case "$cores" in
         8)      echo 2568 ;;   # keep partitions moderate to reduce overhead
	16|32|64|128|160)echo 2560 ;;
        *)       echo 1024 ;;  # safe fallback for unexpected core counts
      esac
      ;;
    LogisticRegression)
      case "$cores" in
	#8|16|32)  echo 252 ;;
	#64|128)   echo 512 ;;
	8|16)    echo 2608 ;;
	32)      echo 2592 ;;
	64|128|160)echo 2560 ;;
        *)       echo 1024 ;;  # safe fallback for unexpected core counts
      esac
      ;;
    *)
      echo 1024
      ;;
  esac
}

function load_config() {
  local delimiter=":"

  # mappings [benchmark, mutators]->[H1_SIZE, MEM_BUDGET]
  # UPDATED: output is now H1_SIZE:MEM_BUDGET:PARTITIONS
  declare -A CONFIG_MAP=(
    ["LinearRegression${delimiter}4"]="54:70"
    ["LinearRegression${delimiter}8"]="54:70"
    ["LinearRegression${delimiter}16"]="54:70"
    ["LinearRegression${delimiter}32"]="54:70"
    ["LinearRegression${delimiter}64"]="80:104"
    ["LinearRegression${delimiter}128"]="80:104"
    ["LinearRegression${delimiter}160"]="54:70"

    ["LogisticRegression${delimiter}4"]="54:70"
    ["LogisticRegression${delimiter}8"]="54:70"
    ["LogisticRegression${delimiter}16"]="54:70"
    ["LogisticRegression${delimiter}32"]="54:70"
    #["LogisticRegression${delimiter}8"]="128:152"
    #["LogisticRegression${delimiter}16"]="128:152"
    #["LogisticRegression${delimiter}32"]="128:152"
    #["LogisticRegression${delimiter}64"]="128:152"
    #["LogisticRegression${delimiter}128"]="128:152"
    ["LogisticRegression${delimiter}160"]="54:70"

    ["PageRank${delimiter}4"]="64:80"
    #["PageRank${delimiter}8"]="120:144" #Native 
    #["PageRank${delimiter}8"]="48:64"
    #["PageRank${delimiter}16"]="48:64"
    #["PageRank${delimiter}32"]="48:64"
    #["PageRank${delimiter}8"]="32:48"
    #["PageRank${delimiter}16"]="32:48"
    #["PageRank${delimiter}32"]="32:48"
    #["PageRank${delimiter}8"]="24:40"
    #["PageRank${delimiter}16"]="24:40"
    #["PageRank${delimiter}32"]="24:40"
    #["PageRank${delimiter}64"]="64:80"
    #["PageRank${delimiter}128"]="64:80"
    ["PageRank${delimiter}8"]="200:224"
    ["PageRank${delimiter}16"]="200:224"
    ["PageRank${delimiter}32"]="200:224"
    ["PageRank${delimiter}64"]="200:224"
    ["PageRank${delimiter}128"]="200:224"
    #["PageRank${delimiter}8"]="128:152"
    #["PageRank${delimiter}16"]="128:152"
    #["PageRank${delimiter}32"]="128:152"
    #["PageRank${delimiter}64"]="128:152"
    #["PageRank${delimiter}128"]="128:152"
    ["PageRank${delimiter}160"]="200:224"

    ["ConnectedComponent${delimiter}4"]="68:84"
    #["ConnectedComponent${delimiter}8"]="52:68"
    #["ConnectedComponent${delimiter}16"]="52:68"
    #["ConnectedComponent${delimiter}32"]="52:68"
    #["ConnectedComponent${delimiter}8"]="32:48"
    #["ConnectedComponent${delimiter}16"]="32:48"
    #["ConnectedComponent${delimiter}32"]="32:48"
    #["ConnectedComponent${delimiter}8"]="24:40"
    #["ConnectedComponent${delimiter}16"]="24:40"
    #["ConnectedComponent${delimiter}32"]="24:40"
    #["ConnectedComponent${delimiter}64"]="68:84"
    #["ConnectedComponent${delimiter}128"]="68:84"
    #["ConnectedComponent${delimiter}8"]="128:152"
    #["ConnectedComponent${delimiter}16"]="128:152"
    #["ConnectedComponent${delimiter}32"]="128:152"
    #["ConnectedComponent${delimiter}64"]="128:152"
    ["ConnectedComponent${delimiter}8"]="200:224"
    ["ConnectedComponent${delimiter}16"]="200:224"
    ["ConnectedComponent${delimiter}32"]="200:224"
    ["ConnectedComponent${delimiter}64"]="200:224"
    ["ConnectedComponent${delimiter}128"]="200:224"
    ["ConnectedComponent${delimiter}160"]="200:224"
  )

  # Output format:
  #   Benchmark:Cores=H1_SIZE:MEM_BUDGET:PARTITIONS
  for key in "${!CONFIG_MAP[@]}"; do
    local bench="${key%%${delimiter}*}"
    local cores="${key##*${delimiter}}"

    local hm="${CONFIG_MAP[$key]}"   # "H1:MEM"
    local parts
    parts="$(get_partitions "$bench" "$cores")"

    echo "$key=${hm}${delimiter}${parts}"
  done
}
