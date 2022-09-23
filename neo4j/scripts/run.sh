#!/usr/bin/env bash

###################################################
#
# file: run.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  26-02-2022 
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to run Giraph benchmarks
#
###################################################

. ./conf.sh

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-h]"
    echo
    echo "Options:"
    echo "      -n  Number of Runs"
    echo "      -o  Output Path"
    echo "      -c  Run with TeraHeap"
    echo "      -s  Run natively"
    echo "      -p  Enable perf tool"
    echo "      -f  Enable profiler tool"
    echo "      -b  Run experiments with custom benchmark"
    echo "      -j  Enable metrics for JIT compiler"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Drop caches
drop_caches() {
  sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >> "$LOG" 2>&1
}

# Check if you have system_util. If not then download it
download_system_util() {
  if [ ! -d "system_util" ]
  then
    git clone git@github.com:jackkolokasis/system_util.git >> "${LOG}" 2>&1
  fi
}

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ "$1" -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]" >> "$LOG"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]" >> "$LOG" 
    fi
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
        kill -2 "${perf_id}"
    done
}

##
# Description: 
#   Kill running background processes (jstat, serdes)
#
# Arguments:
#   $1 - Restart Spark
##
kill_back_process() {
  local jstatPID
  local serdesPID
  local perfPID

  jstatPID=$(pgrep jstat)
  serdesPID=$(pgrep serdes)
  perfPID=$(pgrep perf)

  # Kill all jstat process
  for jstat_pid in ${jstatPID}
  do
    kill -KILL "${jstat_pid}"
  done

  # Kill all serdes process
  for serdes_pid in ${serdesPID}
  do
    kill -KILL "${serdes_pid}"
  done

  # Kill all perf process
  for perf_id in ${perfPID}
  do
    kill -KILL "${perf_id}"
  done
}

##
# Description: 
#   Remove executors log files
##
cleanWorkDirs() {
	rm -rf "${BENCHMARK_SUITE}/report/*"
}

##
# Description
#	Enable perf events
##
enable_perf_event() {
	sudo sh -c 'echo -1 >/proc/sys/kernel/perf_event_paranoid'
	retValue=$?
	message="Enable perf events" 
	check ${retValue} "${message}"
}

##
# Description
#	Update number of compute threads in configuration
#
# Arguments
#	$1: Benchmark
#	$2: Indicate if we run S/D experiment, TeraHeap otherwise
##
update_conf() {
	local bench=$1
	local heap_size
	local is_ser=$2
	local check
	
  heap_size=$(( HEAP * 1024 ))
	
  # Set dataset name
	sed -i '/benchmark.custom.graphs/c\benchmark.custom.graphs = '"$DATASET_NAME" \
		"${BENCHMARK_CONFIG}/benchmarks/custom.properties"

	# Set benchmark
	sed -i '/benchmark.custom.algorithms/c\benchmark.custom.algorithms = '"$bench" \
		"${BENCHMARK_CONFIG}/benchmarks/custom.properties"
	
  if  [ -z "$is_ser" ]
  then
    # Set heap size
    sed -i '/benchmark.runner.max-memory/c\benchmark.runner.max-memory = '"${H1_AND_H2_SIZE}g" \
      "${BENCHMARK_CONFIG}/benchmark.properties"
  else
    sed -i '/benchmark.runner.max-memory/c\benchmark.runner.max-memory = '"${HEAP}g" \
      "${BENCHMARK_CONFIG}/benchmark.properties"
  fi

	if  [ -z "$is_ser" ]
	then
    th_size=$(( (H1_AND_H2_SIZE - HEAP) * 1024 * 1024 * 1024 ))

    jvmOpts="-XX:-ClassUnloading -XX:+UseParallelGC \
      -XX:-UseParallelOldGC -XX:ParallelGCThreads=${GC_THREADS} \
      -XX:+EnableTeraHeap -XX:TeraHeapSize=${th_size} -Xms${HEAP}g \
      -XX:-ResizeTLAB -XX:-UseCompressedOops -XX:-UseCompressedClassPointers \
      -XX:+TeraHeapStatistics -XX:TeraStripeSize=${STRIPE_SIZE} \
      -Xlogth:${TH_STATS_FILE}"
	else
    jvmOpts="-XX:AllocateHeapAt=/mnt/fmap -XX:-ClassUnloading -XX:+UseParallelGC \
      -XX:-UseParallelOldGC -XX:ParallelGCThreads=${GC_THREADS} -XX:-ResizeTLAB \
      -XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
	fi
    
  sed -i '/benchmark.runner.extra-jvm-opts/c\benchmark.runner.extra-jvm-opts = '"${jvmOpts}" \
    "${BENCHMARK_CONFIG}/benchmark.properties"

  sed -i '/jvm.heap.size.mb/c\jvm.heap.size.mb='"${heap_size}" \
    "${BENCHMARK_CONFIG}/neo4j.properties"

  sed -i '/dbms.memory.heap.max_size/c\dbms.memory.heap.max_size='"${HEAP}G" \
    "${BENCHMARK_CONFIG}/neo4j.properties"
  
  sed -i '/dbms.memory.pagecache.size/c\dbms.memory.pagecache.size='"${PAGE_CACHE}G" \
    "${BENCHMARK_CONFIG}/neo4j.properties"
}

# Create a cgroup
setup_cgroup() {
	# Change user/group IDs to your own
	sudo cgcreate -a kolokasis:carvsudo -t kolokasis:carvsudo -g memory:memlim
	cgset -r memory.limit_in_bytes="$MEM_BUDGET" memlim
}

# Delete a cgroup
delete_cgroup() {
	sudo cgdelete memory:memlim
}
##
# Description: 
#   Console Message
#
# Arguments:
#   $1 - Device Name
#   $2 - Workload Name
#
##
printStartMsg() {
    echo
    echo "============================================="
    echo 
    echo "EXPERIMENTS"
    echo
    echo "      DEVICE   : $1"
    echo "      WORKLOAD : $2"
    echo -n "      ITERATION: "
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
# Description:
#	Average Time
#
# Arguments:
#	$1: Result Directory
#	$2: Iterations 
#	$3: Indicate that with S/D, TeraHeap otherwise
##
calculate_avg() {
	local bench_dir=$1 iter=$2
	local exec_time minor_gc major_gc
	local avg_exec_time=0 avg_minor_gc_time=0 avg_major_gc_time=0
	local other=0 max min max_index min_index sum

	cd ${bench_dir}

	for d in $(ls -l | grep '^d' | awk '{print $9}')
	do
		exec_time+=($(grep -w "TOTAL_TIME" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
		minor_gc+=($(grep -w "MINOR_GC" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
		major_gc+=($(grep -w "MAJOR_GC" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
	done

	# Remove outliers (maximum and the minimum) 
	max=$(echo "${exec_time[*]}" | tr ' ' '\n' | sort -nr | head -n 1)
	min=$(echo "${exec_time[*]}" | tr ' ' '\n' | sort -nr | tail -n 1)

	# Finda the max and min values indexes
	max_index=$(echo ${exec_time[*]} | tr ' ' '\n' | awk '/'"${max}"'/ {print NR-1}')
	min_index=$(echo ${exec_time[*]} | tr ' ' '\n' | awk '/'"${min}"'/ {print NR-1}')

	# Remove the max and min values using indexes from all arrays
	unset 'exec_time[$max_index]'
	unset 'exec_time[$min_index]'
	unset 'minor_gc[$max_index]'
	unset 'minor_gc[$min_index]'
	unset 'major_gc[$max_index]'
	unset 'major_gc[$min_index]'

	sum=$(echo "scale=2; ${exec_time[@]/%/ +} 0" | bc -l)
	avg_exec_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)

	sum=$(echo "scale=2; ${minor_gc[@]/%/ +} 0" | bc -l)
	avg_minor_gc_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)

	sum=$(echo "scale=2; ${major_gc[@]/%/ +} 0" | bc -l)
	avg_major_gc_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)
	
	other=$(echo "scale=2; ${avg_exec_time} - ${avg_major_gc_time} - ${avg_minor_gc_time}" | bc -l)

  {
    echo "---------,-------"
    echo "COMPONENT,TIME(s)"
    echo "---------,-------"
    echo "AVG_TOTAL_TIME,$avg_exec_time"

    echo "AVG_OTHER,$other"
    echo "AVG_MINOR_GC,$avg_minor_gc_time"
    echo "AVG_MAJOR_GC,$avg_major_gc_time"
  } >> time.csv

  cd - > /dev/null || exit
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
    echo "============================================="
    echo
}

# Check for the input arguments
while getopts ":n:o:m:cspkajfdbh" opt
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
    c)
			TH=true
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
		m)
			BENCH_DIR=${OPTARG}
			calculate_avg "$BENCH_DIR" "$ITER"
			exit 1
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
TIME=$(date +"%T-%d-%m-%Y")

OUT="${OUTPUT_PATH}_${TIME}"
mkdir -p "$OUT"

enable_perf_event

# Run each benchmark
for benchmark in "${BENCHMARKS[@]}"
do
  printStartMsg "$DEV_TH" "$benchmark"
  STARTTIME=$(date +%s)

	mkdir -p "${OUT}/${benchmark}"
        
	# For every iteration
	for ((i=0; i<TOTAL_CONFS; i++))
	do
		mkdir -p "${OUT}/${benchmark}/conf${i}"

		# For every configuration
		for ((j=0; j<ITER; j++))
		do
			printMsgIteration "$j"

			mkdir -p "${OUT}/${benchmark}/conf${i}/run${j}"
			RUN_DIR="${OUT}/${benchmark}/conf${i}/run${j}"

			# Prepare devices for TeraHeap
			if [ $SERDES ]
			then
				./dev_setup.sh
			else
				./dev_setup.sh -t
			fi

      setup_cgroup

			update_conf "$benchmark" ${SERDES}

			if [ -z "$JIT" ]
			then
				# Collect statics only for the garbage collector
				./jstat.sh "$RUN_DIR" 1 0 &
			else
				# Collect statics for garbage collector and JIT
				./jstat.sh "$RUN_DIR" 1 1 &
			fi
			
			if [ $PERF_TOOL ]
			then
				# Count total cache references, misses and pagefaults
				./perf.sh "$RUN_DIR"/perf.txt 1 &

      fi
			./serdes.sh "$RUN_DIR"/serdes.txt 1 &

			# Enable profiler
			if [ ${PROFILER} ]
			then
				./profiler.sh "$RUN_DIR"/profile.svg 1 &
			fi

      drop_caches

      download_system_util

      # System statistics start
			./system_util/start_statistics.sh -d "$RUN_DIR"

			cd "$BENCHMARK_SUITE" || exit

			# Run benchmark and save output to tmp_out.txt
      cgexec -g memory:memlim	./bin/sh/run-benchmark.sh >> "$LOG" 2>&1

      cd - > /dev/null || exit

      delete_cgroup
				
			if [ $PERF_TOOL ]
			then
				# Stop perf monitor
				stop_perf
      fi

      # System statistics stop
      ./system_util/stop_statistics.sh -d "${RUN_DIR}"

			# Parse cpu and disk statistics results
			./system_util/extract-data.sh -r "${RUN_DIR}" -d "${DEV_TH}" \
				-d "${DEV_NEO4J_DB}" >> "${LOG}" 2>&1

			# Copy the confifuration to the directory with the results
			cp ./conf.sh "${RUN_DIR}/"

			cp -r "$BENCHMARK_SUITE/report/*-*-*-report-*/log/benchmark-summary.log" "${RUN_DIR}/"
			cp -r "$BENCHMARK_SUITE/report/*-*-*-report-*/log/benchmark-full.log" "${RUN_DIR}/"
			cp -r "$BENCHMARK_SUITE/report/bench.log" "${RUN_DIR}/"

      if [ $TH ]
      then
        cp -r "$BENCHMARK_SUITE/report/teraHeap.txt" "${RUN_DIR}/"
      fi

			if [ $TH ]
			then
				./parse_results.sh -d "$RUN_DIR" -t  >> "$LOG" 2>&1
			else
				./parse_results.sh -d "$RUN_DIR" >> "$LOG" 2>&1
			fi

			# Check if the run completed succesfully. If the run fail then retry
			# to run the same iteration
			check=$(grep "TOTAL_TIME" "${RUN_DIR}"/result.csv | awk -F ',' '{print $2}')
			if [ -z "$check" ]  
			then
				j=$((j - 1))
			fi
		done

		if [ "$ITER" -ge 3 ]
		then
			# Calculate Average
			calculate_avg "${OUT}/${benchmark}/conf${i}" "$ITER"
		fi
			
    rm -rf "$BENCHMARK_SUITE"/report/*
	done

	ENDTIME=$(date +%s)
	printEndMsg "$STARTTIME" "$ENDTIME"
done
