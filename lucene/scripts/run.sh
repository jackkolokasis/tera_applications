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

BENCHMARKS=( "M1" )

SETUP="NATIVE"
GEN_ARGS=()

# Print error/usage script message
usage() {
  echo
  echo "Usage:"
  echo -n "      $0 [option ...] [-h]"
  echo
  echo "Options:"
  echo "      -n  Number of Runs"
  echo "      -o  Output Path"
  echo "      -t  Enable TeraHeap"
  echo "      -g  Number of GC Threads"
  echo "          [Default: 16]"
  echo "      -m  Memory Budget"
  echo "          [<x>G where x is a number  | Default: 60G]"
  echo "      -D  Disable QueryCache"
  echo "      -e  Number of QueryCache entries"
  echo "          [Default: 3000000]"
  echo "      -s  Enable statistics"
  echo "      -H  Ratio (%) Heap/PageCache (TeraHeap configuration)"
  echo "          [Default is 55]"
  echo "      -Q  Ratio (%) QueryCache/Heap (Native configuration)"
  echo "          [Default is 50]"
  echo "      -k  Kill background processes"
  echo "      -h  Show usage"
  echo
}

LOGIN=$(whoami)
GROUP_ID="sudo"

##
# Description:
#   Create a cgroup
setup_cgroup() {
	# Change user/group IDs to your own
  sudo cgcreate -a ${LOGIN}:${GROUP_ID} -t ${LOGIN}:${GROUP_ID} -g memory:memlim
  cgset -r memory.limit_in_bytes="$MEM_BUDGET" memlim

  if [ ! -f ./run_cgexec.sh ]; then
    {
      echo "#!/usr/bin/env bash"
      echo '"$@"'
    } > ./run_cgexec.sh
  fi

  clean_exports

  # Add the proper exports in the script that we use to execute
  # processes under cgroups
  sed -i '2i\
    export JAVA_HOME='${JAVA_PATH}'\
    export LIBRARY_PATH='${TERAHEAP_REPO}'/allocator/lib:$LIBRARY_PATH\
    export LD_LIBRARY_PATH='${TERAHEAP_REPO}'/allocator/lib:$LD_LIBRARY_PATH\
    export PATH='${TERAHEAP_REPO}'/allocator/include/:$PATH\
    export LIBRARY_PATH='${TERAHEAP_REPO}'/tera_malloc/lib:$LIBRARY_PATH\
    export LD_LIBRARY_PATH='${TERAHEAP_REPO}'/tera_malloc/lib:$LD_LIBRARY_PATH\
    export LD_LIBRARY_PATH=/home1/public/'${LOGIN}'/hsdis/build/linux-amd64/:$LD_LIBRARY_PATH\
    export PATH='${TERAHEAP_REPO}'/tera_malloc/include/:$PATH' ./run_cgexec.sh
}

run_cgexec() {
  cgexec -g memory:memlim --sticky ./run_cgexec.sh "$@"
}

##
# Description:
#   Delete a cgroup
delete_cgroup() {
	sudo cgdelete memory:memlim > /dev/null 2>&1
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
  for perf_id in ${perfPID}
  do
    kill -2 "${perf_id}" >> "${BENCH_LOG}" 2>&1
  done
}

##
# Description: 
#   Kill running background processes (jstat, serdes)
##
kill_back_process() {
  pkill -u $LOGIN -f "bash ./mem_usage.sh"
  pkill -u $LOGIN -f "bash ./jstat.sh"
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
  
  if [ ! -d "system_util" ]
  then
    # subprocess to limit variable scope from `conf.tmpl.sh`
    (
      . ./conf.tmpl.sh # for BENCH_LOG var
      git clone https://github.com/jackkolokasis/system_util.git >> "${BENCH_LOG}" 2>&1
    )
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
  FORMATED="$(( ELAPSEDTIME / 3600))h:$(( ELAPSEDTIME % 3600 / 60))m:$(( ELAPSEDTIME % 60))s"  
  echo
  echo
  echo "    Benchmark Time Elapsed: $FORMATED"
  echo
  echo "====================================================================="
  echo
}

##
# Function to kill the watch process
kill_watch() {
  #pkill -f "watch -n 1"
  kill -9 "$(pgrep -f "mem_usage.sh")" >/dev/null 2>&1
}

clean_exports() {
  # Remove export statements and save the cleaned content back to the file
  grep -v "export " ./run_cgexec.sh > ./run_cgexec.sh.tmp
  mv ./run_cgexec.sh.tmp ./run_cgexec.sh
  chmod +x ./run_cgexec.sh
}

prologue() {
  echo "--------------------------"
  echo "- TeraHeap:         $ENABLE_TERAHEAP"
  echo "- GC Threads:       $GC_THREADS"
  echo "- H1 Size:          $H1_SIZE"
  echo "- Memory Budget:    $MEM_BUDGET"
  echo "- QueryCache Size:  $QUERY_CACHE"
  echo "-------------------------"
}

# Check for the input arguments
while getopts "n:o:kthg:m:De:s" opt
do
  case "${opt}" in
    n)
      ITER=${OPTARG}
      ;;
    o)
      OUTPUT_PATH=${OPTARG}
      ;;
    k)
      kill_back_process
      exit 1
      ;;
    t)
      SETUP="TERAHEAP"
      GEN_ARGS+=( "-t" )
      ;;
    # Generate Conf flags
    g|m|e|H|Q)
      GEN_ARGS+=( "-$opt" "$OPTARG" )
      ;;
    D|s)
      GEN_ARGS+=( "-$opt" )
      ;;
    # -------------------
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# Create directory for the results if do not exist
TIME=$(date +"%T-%d-%m-%Y")

OUT="${OUTPUT_PATH}_${TIME}"
OUT=$(pwd)/${OUT} 
mkdir -p "${OUT}"

download_third_party

# Run each benchmark
for benchmark in "${BENCHMARKS[@]}"
do
  ./gen-conf.sh ${GEN_ARGS[@]}
  . ./conf.sh
  TOTAL_CONFS=1

  prologue

  printStartMsg "${benchmark}"
  STARTTIME=$(date +%s)

  mkdir -p "${OUT}/${benchmark}"

  # For every iteration
  for ((i=0; i<ITER; i++))
  do
    mkdir -p "${OUT}/${benchmark}/run${i}"

    # For every configuration
    for ((j=0; j<TOTAL_CONFS; j++))
    do
      mkdir -p "${OUT}/${benchmark}/run${i}/conf${j}"
      RUN_DIR="${OUT}/${benchmark}/run${i}/conf${j}"

      setup_cgroup

      # Collect statics only for the garbage collector
      ./jstat.sh "${RUN_DIR}"/jstat &

      # Monitor memory
      ./mem_usage.sh "${RUN_DIR}"/mem_usage.txt &

      # Drop caches
      echo 3 | sudo tee -a /proc/sys/vm/drop_caches >> /dev/null 2>&1

      # System statistics start
      ./system_util/start_statistics.sh -d "${RUN_DIR}"

      run_cgexec ./run_benchmark.sh "${RUN_DIR}" "${benchmark}" "${SETUP}"

      # Kil watch process
      kill_watch

      # System statistics stop
      ./system_util/stop_statistics.sh -d "${RUN_DIR}"

      delete_cgroup

      ./system_util/extract-data.sh -r "${RUN_DIR}" -d "${DEV_DATASET}" >> "${BENCH_LOG}" 2>&1

      # Parse results
      if [ $SETUP == "TERAHEAP" ]
      then
        ./parse_results.sh -d "${RUN_DIR}" -b "${benchmark}" -H ${H1_SIZE} -m ${MEM_BUDGET} -t
      else
        ./parse_results.sh -d "${RUN_DIR}" -b "${benchmark}" -H ${H1_SIZE} -m ${MEM_BUDGET}
      fi

      cp ./conf.sh "${RUN_DIR}/conf.sh"
    done
  done

  ENDTIME=$(date +%s)
  printEndMsg "${STARTTIME}" "${ENDTIME}"
done

exit
