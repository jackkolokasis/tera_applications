#!/usr/bin/env bash

###################################################
#
# file: run.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  20-01-2021
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to run the experiments
#
###################################################

. ./conf.sh

#### Global Variables ####
CUSTOM_BENCHMARK=false
RUN_TPCDS=false

# Print error/usage script message
usage() {
  echo
  echo "Usage:"
  echo -n "      $0 [option ...] [-h]"
  echo
  echo "Options:"
  #echo "      -a  allocation_mode        [0: H1, 1: H1H2, 2: H2H1]"
  echo "      -n  Number of Runs"
  echo "      -o  Output Path"
  echo "      -t  Enable TeraHeap"
  echo "      -s  Enable serialization/deserialization"
  echo "      -p  Enable perf tool"
  echo "      -f  Enable profiler tool"
  #echo "      -a  Run experiments with high bench"
  echo "      -b  Run experiments with custom benchmark"
  echo "      -q  Run experiments with TPC-DS workloads"
  echo "      -j  Enable metrics for JIT compiler"
  echo "      -h  Show usage"
  echo

  exit 1
}

# Function to parse results if execution is errors free
run_results_parser() {
  local run_dir=$1         # The directory containing the logs of a worker
  local executors_count=$2 # number of executors
  local mode=$3            # -t for FlexHeap, -s for Native

  # Count the number of subdirectories, excluding the directory itself
  local subdir_count=$(find "$app_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)

  # Check if the number of subdirectories is greater than 1
  if [ "$subdir_count" -gt 1 ]; then
    echo "The directory '$run_dir' contains $subdir_count subdirectories."
  else
    echo "The directory '$run_dir' contains $subdir_count subdirectory."
    ./parse_results.sh -d "${run_dir}" -n "${executors_count}" $mode
  fi
  ./jvm_error_filter.sh -i $run_dir
}

build_async_profiler() {
  export JAVA_HOME=${MY_JAVA_HOME}

  cd ../../util/ || exit

  if [ ! -d async-profiler ]; then
    cpu_arch=$(uname -p)
    if [ $cpu_arch == x86_64 ]; then
      wget https://github.com/async-profiler/async-profiler/releases/download/v2.9/async-profiler-2.9-linux-x64.tar.gz >>"${BENCH_LOG}" 2>&1
      tar xf async-profiler-2.9-linux-x64.tar.gz >>"${BENCH_LOG}" 2>&1
      mv async-profiler-2.9-linux-x64 async-profiler
    elif [ $cpu_arch == aarch64 ]; then
      wget https://github.com/async-profiler/async-profiler/releases/download/v2.9/async-profiler-2.9-linux-arm64.tar.gz >>"${BENCH_LOG}" 2>&1
      tar xf async-profiler-2.9-linux-arm64.tar.gz >>"${BENCH_LOG}" 2>&1
      mv async-profiler-2.9-linux-arm64 async-profiler
    else
      echo "Unsupported architecture!"
    fi
  fi

  cd - >/dev/null || exit
}

##
# Description:
#   Create a cgroup
setup_cgroup() {
  # Change user/group IDs to your own
  sudo cgcreate -a $USER:carvsudo -t $USER:carvsudo -g memory:memlim
  cgset -r memory.limit_in_bytes="$MEM_BUDGET" memlim
  #sudo cgset -r memory.numa_stat=0 memlim
}

##
# Description:
#   Delete a cgroup
delete_cgroup() {
  sudo cgdelete memory:memlim >/dev/null 2>&1
}

run_cgexec() {
  cgexec -g memory:memlim --sticky ./run_cgexec.sh "$@"
}

##
# Description:
#   Start Spark
##
start_spark() {
  if [[ $USE_CGROUPS == true ]]; then
    setup_cgroup
    run_cgexec "${SPARK_DIR}"/sbin/start-all.sh >>"${BENCH_LOG}" 2>&1
  else
    "${SPARK_DIR}"/sbin/start-all.sh >>"${BENCH_LOG}" 2>&1
  fi
}

##
# Description:
#   Stop Spark
##
stop_spark() {
  if [[ $USE_CGROUPS == true ]]; then
    run_cgexec "${SPARK_DIR}"/sbin/stop-all.sh >>"${BENCH_LOG}" 2>&1
  else
    "${SPARK_DIR}"/sbin/stop-all.sh >>"${BENCH_LOG}" 2>&1
  fi
  #kill all the processes of Spark
  xargs -a /sys/fs/cgroup/memory/memlim/cgroup.procs kill
}

##
# Description:
#   Stop perf monitor statistics with signal interupt (SIGINT)
#
##
stop_perf() {
  local perfPID
  perfPID=$(pgrep perf)

  # Kill all perf process
  for perf_id in ${perfPID}; do
    kill -2 "${perf_id}" >>"${BENCH_LOG}" 2>&1
  done
}

##
# Description:
#   Kill running background processes (jstat, serdes)
##
kill_back_process() {
  local jstatPID
  local serdesPID
  local perfPID

  jstatPID=$(pgrep jstat)
  serdesPID=$(pgrep serdes)
  perfPID=$(pgrep perf)

  # Kill all jstat process
  for jstat_pid in ${jstatPID}; do
    kill -KILL "${jstat_pid}" >>"${BENCH_LOG}" 2>&1
  done

  # Kill all serdes process
  for serdes_pid in ${serdesPID}; do
    kill -KILL "${serdes_pid}" >>"${BENCH_LOG}" 2>&1
  done

  # Kill all perf process
  for perf_id in ${perfPID}; do
    kill -KILL "${perf_id}" >>"${BENCH_LOG}" 2>&1
  done
}

##
# Description:
#   Remove executors log files
##
cleanWorkDirs() {

  cd "${SPARK_DIR}"/work || exit

  for f in $(ls); do
    if [[ $f == "app-"* ]]; then
      rm -rf "${f}"
    fi
  done

  cd - >/dev/null || exit
}

##
# Description:
#   Console Message
#
# Arguments:
#   $1 - Iteration
##
printMsgIteration() {
  echo -n "$1 "
}

##
# Descrition:
#   Download third party repos if does not exist
download_third_party() {
  if [ ! -d "system_util" ]; then
    #git clone https://github.com/jackkolokasis/system_util.git >> "${BENCH_LOG}" 2>&1
    git clone https://github.com/perpap/system_util.git >>"${BENCH_LOG}" 2>&1
  fi
}

##
# Description:
#   Console Message
#
# Arguments:
#   $1 - Workload Name
#
##
printStartMsg() {
  echo
  echo "====================================================================="
  echo
  echo "EXPERIMENTS"
  echo
  echo "      WORKLOAD : $1"
  echo -n "      ITERATION: "
}

##
# Description:
#   Console Message
#
# Arguments:
#   $1 - End Time
#   $2 - Start Time
#
##
printEndMsg() {
  ELAPSEDTIME=$(($2 - $1))
  FORMATED="$((ELAPSEDTIME / 3600))h:$((ELAPSEDTIME % 3600 / 60))m:$((ELAPSEDTIME % 60))s"
  echo
  echo
  echo "    Benchmark Time Elapsed: $FORMATED"
  echo
  echo "====================================================================="
  echo
}

gen_config_files() {
  if [ "$SERDES" ]; then
    cp ./configs/native/spark-defaults.conf "${SPARK_DIR}"/conf
  else
    cp ./configs/teraheap/spark-defaults.conf "${SPARK_DIR}"/conf
  fi

  mkdir -p "${SPARK_DIR}"/work
  mkdir -p "${SPARK_DIR}"/logs
}

##
# Function to kill the watch process
kill_watch() {
  #pkill -f "watch -n 1"
  kill -9 "$(pgrep -f "mem_usage.sh")" >/dev/null 2>&1
}

# Check for the input arguments
while getopts ":n:o:ktspjfbqh" opt; do
  case "${opt}" in
  n)
    ITER=${OPTARG}
    ;;
  o)
    OUTPUT_PATH="${OPTARG}/NATIVE"
    ;;
  k)
    kill_back_process
    exit 1
    ;;
  t)
    TH=true
    # Replace "NATIVE" with "FLEXHEAP"
    OUTPUT_PATH=${OUTPUT_PATH//NATIVE/FLEXHEAP}
    ;;
  s)
    SERDES=true
    ;;
  p)
    PERF_TOOL=true
    ;;
  j)
    JIT=true
    ;;
  f)
    PROFILER=true
    ;;
  b)
    CUSTOM_BENCHMARK=true
    ;;
  q)
    RUN_TPCDS=true
    ;;
  h)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

# Create directory for the results if do not exist
TIME=$(date +"%d-%m-%Y-%T")

OUT="${OUTPUT_PATH}"
#echo "Create directory OUT=$OUT"
mkdir -p "${OUT}"

# Enable perf event
sudo sh -c 'echo -1 >/proc/sys/kernel/perf_event_paranoid'
sudo sh -c 'echo -0 >/proc/sys/kernel/kptr_restrict'

gen_config_files

download_third_party

build_async_profiler

# Run each benchmark
for benchmark in "${BENCHMARKS[@]}"; do
  printStartMsg "${benchmark}"
  STARTTIME=$(date +%s)

  mkdir -p "${OUT}/${benchmark}/PARTITIONS=${NUM_OF_PARTITIONS}_REGION_SIZE=$((REGION_SIZE / 1024 / 1024))_EXECUTORS=${NUM_EXECUTORS}_MUTATORS=${EXEC_CORES}_GCTHREADS=${GC_THREADS}_MEMBUDGET=${MEM_BUDGET}_H1=${H1_SIZE}G_H1H2=${H1_H2_SIZE}G_${TIME}"

  # For every iteration
  for ((i = 0; i < ITER; i++)); do
    mkdir -p "${OUT}/${benchmark}/PARTITIONS=${NUM_OF_PARTITIONS}_REGION_SIZE=$((REGION_SIZE / 1024 / 1024))_EXECUTORS=${NUM_EXECUTORS}_MUTATORS=${EXEC_CORES}_GCTHREADS=${GC_THREADS}_MEMBUDGET=${MEM_BUDGET}_H1=${H1_SIZE}G_H1H2=${H1_H2_SIZE}G_${TIME}/run${i}"
    # For every configuration
    for ((j = 0; j < TOTAL_CONFS; j++)); do
      mkdir -p "${OUT}/${benchmark}/PARTITIONS=${NUM_OF_PARTITIONS}_REGION_SIZE=$((REGION_SIZE / 1024 / 1024))_EXECUTORS=${NUM_EXECUTORS}_MUTATORS=${EXEC_CORES}_GCTHREADS=${GC_THREADS}_MEMBUDGET=${MEM_BUDGET}_H1=${H1_SIZE}G_H1H2=${H1_H2_SIZE}G_${TIME}/run${i}/conf${j}"
      RUN_DIR="${OUT}/${benchmark}/PARTITIONS=${NUM_OF_PARTITIONS}_REGION_SIZE=$((REGION_SIZE / 1024 / 1024))_EXECUTORS=${NUM_EXECUTORS}_MUTATORS=${EXEC_CORES}_GCTHREADS=${GC_THREADS}_MEMBUDGET=${MEM_BUDGET}_H1=${H1_SIZE}G_H1H2=${H1_H2_SIZE}G_${TIME}/run${i}/conf${j}"
      # Set configuration
      if [ $SERDES ]; then
        ./update_conf.sh -b "${CUSTOM_BENCHMARK}"
      else
        ./update_conf_th.sh -b "${CUSTOM_BENCHMARK}"
      fi

      start_spark

      if [ -z "$JIT" ]; then
        # Collect statics only for the garbage collector
        ./jstat.sh "${RUN_DIR}"/jstat "${NUM_EXECUTORS}" 0 &
      else
        # Collect statics for garbage collector and JIT
        ./jstat.sh "${RUN_DIR}"/jstat "${NUM_EXECUTORS}" 1 &
      fi

      # Monitor memory
      ./mem_usage.sh "${RUN_DIR}"/mem_usage.txt "${NUM_EXECUTORS}" &

      if [ $PERF_TOOL ]; then
        # Count total cache references, misses and pagefaults
        ./perf.sh ${RUN_DIR}/perf ${NUM_EXECUTORS} &
      fi

      ./serdes.sh ${RUN_DIR}/serdes ${NUM_EXECUTORS} &

      # Enable profiler
      if [ ${PROFILER} ]; then
        ./profiler.sh ${RUN_DIR}/profile.svg ${NUM_EXECUTORS} &
      fi

      # Drop caches
      sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >>"${BENCH_LOG}" 2>&1

      # Pmem stats before
      if [[ ${DEV_FMAP} == *pmem* ]]; then
        sudo ipmctl show -performance >>"${RUN_DIR}/pmem_before.txt"
      fi

      # System statistics start
      ./system_util/start_statistics.sh -d "${RUN_DIR}"

      if [ $CUSTOM_BENCHMARK == "true" ]; then
        if [ $RUN_TPCDS == "true" ]; then
          run_cgexec ./run_tpcds.sh "${RUN_DIR}" "${H1_SIZE[$j]}" "${benchmark}"
        else
          run_cgexec ./custom_benchmarks.sh "${RUN_DIR}" "$SERDES"
        fi
      else
        # Run benchmark and save output to tmp_out.txt
        if [ "$USE_CGROUPS" == true ]; then
          run_cgexec "${SPARK_BENCH_DIR}"/"${benchmark}"/bin/run.sh >"${RUN_DIR}"/tmp_out.txt 2>&1
        else
          "${SPARK_BENCH_DIR}"/"${benchmark}"/bin/run.sh >"${RUN_DIR}"/tmp_out.txt 2>&1
        fi
      fi

      # Kil watch process
      kill_watch

      if [[ ${DEV_FMAP} == *pmem* ]]; then
        # Pmem stats after
        sudo ipmctl show -performance >>"${RUN_DIR}"/pmem_after.txt
      fi

      # System statistics stop
      ./system_util/stop_statistics.sh -d "${RUN_DIR}"

      stop_spark

      #delete_cgroup

      if [ $SERDES ]; then
        # Parse cpu and disk statistics results
        ./system_util/extract-data.sh -r "${RUN_DIR}" -d "${DEV_SHFL}" -d "${DEV_H2}" >>"${BENCH_LOG}" 2>&1
      elif [ $TH ]; then
        # Parse cpu and disk statistics results
        ./system_util/extract-data.sh -r "${RUN_DIR}" -d "${DEV_H2}" -d "${DEV_SHFL}" >>"${BENCH_LOG}" 2>&1
      fi

      # Copy the confifuration to the directory with the results
      cp ./conf.sh "${RUN_DIR}"/

      if [ $CUSTOM_BENCHMARK == "false" ]; then
        # Save the total duration of the benchmark execution
        tail -n 1 "${SPARK_BENCH_DIR}"/num/bench-report.dat >>"${RUN_DIR}"/total_time.txt
      fi

      if [ $PERF_TOOL ]; then
        # Stop perf monitor
        stop_perf
      fi

      # Parse results
      if [ $TH ]; then
        TH_METRICS=$(ls -td "${SPARK_DIR}"/work/* | head -n 1)
        cp "${TH_METRICS}"/0/teraHeap.txt "${RUN_DIR}"/
        ./parse_results.sh -d "${RUN_DIR}" -n "${NUM_EXECUTORS}" -t
      else
        ./parse_results.sh -d "${RUN_DIR}" -n "${NUM_EXECUTORS}" -s
      fi
    done
  done

  ENDTIME=$(date +%s)
  printEndMsg "${STARTTIME}" "${ENDTIME}"
done

exit
