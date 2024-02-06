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
    echo "      -t  Enable TeraHeap"
    echo "      -s  Enable Giraph out-of-core"
    echo "      -p  Enable perf tool"
    echo "      -f  Enable profiler tool"
    echo "      -j  Enable metrics for JIT compiler"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ $1 -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]" >> $LOG
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]" >> $LOG 
    fi
}

##
# Description:
#   Create a cgroup
setup_cgroup() {
	# Change user/group IDs to your own
	sudo cgcreate -a kolokasis:carvsudo -t kolokasis:carvsudo -g memory:memlim
	cgset -r memory.limit_in_bytes="$MEM_BUDGET" memlim

  # Add the proper exports in the script that we use to execute
  # processes under cgroups
  sed -i '2i\
  export JAVA_HOME='${JAVA_PATH}'\
  export LIBRARY_PATH='${TERAHEAP_REPO}'/allocator/lib:$LIBRARY_PATH\
  export LD_LIBRARY_PATH='${TERAHEAP_REPO}'/allocator/lib:$LD_LIBRARY_PATH\
  export PATH='${TERAHEAP_REPO}'/allocator/include/:$PATH\
  export LIBRARY_PATH='${TERAHEAP_REPO}'/tera_malloc/lib:$LIBRARY_PATH\
  export LD_LIBRARY_PATH='${TERAHEAP_REPO}'/tera_malloc/lib:$LD_LIBRARY_PATH\
  export PATH='${TERAHEAP_REPO}'/tera_malloc/include/:$PATH
  ' ./run_cgexec.sh
}

##
# Description:
#   Delete a cgroup
delete_cgroup() {
	sudo cgdelete memory:memlim 
  sed -i '/export/d' ./run_cgexec.sh
}

run_cgexec() {
  cgexec -g memory:memlim --sticky /opt/carvguest/asplos23_ae/tera_applications/giraph/scripts/run_cgexec.sh "$@"
}

##
# Description: 
#   Start Hadoop, Yarn, and Zookeeper
#
# Arguments
#	$1: Indicateds if we ran S/D experiments, TeraHeap otherwise
##
start_hadoop_yarn_zkeeper() {
	local is_ser=$1
	local jvm_opts=""

	if [ -z "${is_ser}" ]
	then
		local tc_size=$(( (900 - HEAP) * 1024 * 1024 * 1024 ))

		jvm_opts="\t\t<value>-XX:-ClassUnloading -XX:+UseParallelGC "
		jvm_opts+="-XX:-UseParallelOldGC -XX:ParallelGCThreads=${GC_THREADS} "
    jvm_opts+="-XX:+EnableTeraHeap "
		jvm_opts+="-XX:TeraHeapSize=${tc_size} -Xmx900g -Xms${HEAP}g "

    local H2_FILE_SZ_BYTES=$(echo "${TH_FILE_SZ} * 1024 * 1024 * 1024" | bc)
    local H2_PATH="${TH_DIR//\//\\/}\/"
    jvm_opts+="-XX:AllocateH2At=\"${H2_PATH}\" -XX:H2FileSize=${H2_FILE_SZ_BYTES} "

    if [ "${DYNAHEAP}" == "true" ]
    then
      jvm_opts+="-XX:+DynamicHeapResizing "
      jvm_opts+="-XX:TeraResizingPolicy=${TERA_RESIZING_POLICY} "
      jvm_opts+="-XX:TeraDRAMLimit=${TERA_DRAM_LIMIT} "
    fi
		jvm_opts+="-XX:-UseCompressedOops " 
		jvm_opts+="-XX:-UseCompressedClassPointers "
    if [ "${PRINT_STATS}" == "true" ]
    then
      jvm_opts+="-XX:+TeraHeapStatistics "
      jvm_opts+="-Xlogth:${BENCHMARK_SUITE//'/'/\\/}\/report\/teraHeap.txt "
    elif [ "${PRINT_EXTENDED_STATS}" == "true" ]
    then
      jvm_opts+="-XX:+TeraHeapStatistics -XX:+TeraHeapCardStatistics "
      jvm_opts+="-Xlogth:${BENCHMARK_SUITE//'/'/\\/}\/report\/teraHeap.txt "
    fi
		jvm_opts+="-XX:TeraStripeSize=${STRIPE_SIZE} -XX:+ShowMessageBoxOnError<\/value>"
	else
		jvm_opts="\t\t<value>-Xmx${HEAP}g -XX:-ClassUnloading -XX:+UseParallelGC "
		jvm_opts+="-XX:-UseParallelOldGC -XX:ParallelGCThreads=${GC_THREADS} -XX:-ResizeTLAB "
		jvm_opts+="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers <\/value>"
		#jvm_opts+="-XX:+TimeBreakDown -Xlogtime:${BENCHMARK_SUITE//'/'/\\/}\/report\/teraCache.txt<\/value>"
	fi

	# Yarn child executor jvm flags
	sed '/java.opts/{n;s/.*/'"${jvm_opts}"'/}' -i "${HADOOP}"/etc/hadoop/mapred-site.xml
	retValue=$?
	message="Update jvm flags" 
	check ${retValue} "${message}"

	# Format Hadoop
	run_cgexec "${HADOOP}"/bin/hdfs namenode -format >> "$LOG" 2>&1
	retValue=$?
	message="Format Hadoop" 
	check ${retValue} "${message}"

	# Start hadoop, yarn, and zookeeper
	run_cgexec "${HADOOP}"/sbin/start-dfs.sh >> "$LOG" 2>&1
	retValue=$?
	message="Start HDFS" 
	check ${retValue} "${message}"

	run_cgexec "${HADOOP}"/sbin/start-yarn.sh >> "$LOG" 2>&1
	retValue=$?
	message="Start Yarn" 
	check ${retValue} "${message}"

	export SERVER_JVMFLAGS="-Xmx4g" 
  run_cgexec "${ZOOKEEPER}"/bin/zkServer.sh start >> "$LOG" 2>&1
	retValue=$?
	message="Start Zookeeper" 
	check ${retValue} "${message}"
  
}

##
# Description:
#   Clear files
##
clear_files() {
	rm -rf "${DATASET_DIR}/hadoop"
  rm -rf "${ZOOKEEPER_DIR}/version-2"
  rm -rf "${ZOOKEEPER_DIR}/zookeeper_server.pid"
}

##
# Description:
#   Cretea necessary files
##
create_files() {
  mkdir -p "${DATASET_DIR}/hadoop"
}

##
# Description: 
#   Stop Hadoop, Yarn, and Zookeeper
##
stop_hadoop_yarn_zkeeper() {
	run_cgexec "${ZOOKEEPER}"/bin/zkServer.sh stop >> "$LOG" 1>&1
	retValue=$?
	message="Stop Zookeeper" 
	check ${retValue} "${message}"
	
	run_cgexec "${HADOOP}"/sbin/stop-yarn.sh >> "$LOG" 2>&1
	retValue=$?
	message="Stop Yarn" 
	check ${retValue} "${message}"

	run_cgexec "${HADOOP}"/sbin/stop-dfs.sh >> "$LOG" 2>&1
	retValue=$?
	message="Stop HDFS" 
	check ${retValue} "${message}"

  # Kill all the processes in the cgroup. In case the group 
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
    for perf_id in ${perfPID}
    do
        kill -2 "${perf_id}"
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

  kill -KILL $(jps | grep "MRApp" | awk '{print $1}')
  kill -KILL $(jps | grep "YarnChild" | awk '{print $1}')
}

##
# Description: 
#   Remove executors log files
##
cleanWorkDirs() {
	rm -rf "${BENCHMARK_SUITE}"/report/*
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
	local heap_size=$(( HEAP * 1024 ))
	local is_ser=$2
	local check
  local command

  # Set dataset
  command="benchmark.custom.graphs = ${DATASET}"
  sed -i 's/benchmark\.custom\.graphs.*/'"${command}"'/' \
    "${BENCHMARK_CONFIG}"/benchmarks/custom.properties 

	# Set benchmark
	sed -i '/benchmark.custom.algorithms/c\benchmark.custom.algorithms = '"$bench" \
		"${BENCHMARK_CONFIG}"/benchmarks/custom.properties 

  # Set benchmark properties
  command="graphs.root-directory = ${DATASET_DIR}/graphalytics/graphs"
  sed -i '/graphs\.root-directory.*/c\'"${command}" \
    "${BENCHMARK_CONFIG}"/benchmark.properties 

  command="graphs.validation-directory = ${DATASET_DIR}/graphalytics/validation"
  sed -i '/graphs\.validation-directory.*/c\'"${command}" \
    "${BENCHMARK_CONFIG}"/benchmark.properties 
  
  command="graphs.output-directory = ${DATASET_DIR}/graphalytics/output"
  sed -i '/graphs\.output-directory.*/c\'"${command}" \
    "${BENCHMARK_CONFIG}"/benchmark.properties 

  # Set address of ZooKeeper deployment (required)
  command="platform.giraph.zoo-keeper-address: ${HOSTNAME}:2181"
  sed -i '/platform.giraph.zoo-keeper-address/c\'"${command}" \
    "${BENCHMARK_CONFIG}"/platform.properties

	# Set heap size
	sed -i '/memory-size/c\platform.giraph.job.memory-size: '"${heap_size}" \
		"${BENCHMARK_CONFIG}"/platform.properties
	sed -i '/heap-size/c\platform.giraph.job.heap-size: '"${heap_size}" \
		"${BENCHMARK_CONFIG}"/platform.properties

  # Set worker cores
	sed -i '/worker-cores/c\platform.giraph.job.worker-cores: '"${COMPUTE_THREADS}" \
		"${BENCHMARK_CONFIG}"/platform.properties

  # Set hadoop home
  command="platform.hadoop.home: ${HADOOP}"
  sed -i '/platform.hadoop.home/c\'"${command}" \
    "${BENCHMARK_CONFIG}"/platform.properties

	# Set number of compute threads
	sed -i '/numComputeThreads/c\platform.giraph.options.numComputeThreads: '"${COMPUTE_THREADS}" \
		"${BENCHMARK_CONFIG}"/platform.properties

	if  [ -z ${is_ser} ]
	then
		sed -i '/useOutOfCoreGraph/c\platform.giraph.options.useOutOfCoreGraph: false' \
			"${BENCHMARK_CONFIG}"/platform.properties
 
		# Check if this line is not commented 
		check=$(grep "^#[a-z].*.partitionsDirectory" "${BENCHMARK_CONFIG}"/platform.properties)
		if [ -z "${check}" ]
		then 
			# Comment these line in the configuration
			sed -e '/platform.giraph.options.partitionsDirectory/s/^/#/' \
				-i "${BENCHMARK_CONFIG}"/platform.properties
		fi
		
		sed -i '/teraheap/c\platform.giraph.options.teraheap.enable: true' \
			"${BENCHMARK_CONFIG}"/platform.properties
	else
		sed -i '/useOutOfCoreGraph/c\platform.giraph.options.useOutOfCoreGraph: true' \
			"${BENCHMARK_CONFIG}"/platform.properties
 
		# Check if this line is commented
		check=$(grep "^#[a-z].*.partitionsDirectory" "${BENCHMARK_CONFIG}"/platform.properties)
		if [ "${check}" ]
		then 
			# Uncomment these lines in the configuration
			sed -e '/platform.giraph.options.partitionsDirectory/s/^#//' \
				-i "${BENCHMARK_CONFIG}"/platform.properties
		fi
		
		sed -i '/teraheap/c\platform.giraph.options.teraheap.enable: false' \
			"${BENCHMARK_CONFIG}"/platform.properties
	fi
}

##
# Description
#	Create, mount and fill ramdisk to reduce server available memory. 
#
# Arguments:
#	$1: Iteration
#	
##
create_ramdisk() {
	local iter=$1

	if [ "${RAMDISK}" -eq 0 ] || [ "${iter}" -gt 0 ]
	then
		return
	fi

	# Check if ramdisk_create_and_mount.sh exists
	if [ ! -f "${RAMDISK_SCRIPT_DIR}/ramdisk_create_and_mount.sh" ]
	then
		cp ramdisk_create_and_mount.sh "${RAMDISK_SCRIPT_DIR}"/
	fi
	
	cd "${RAMDISK_SCRIPT_DIR}" || exit

	# If a previous ramdisk exist then remove it
	if [ ! -z "$(lsmod | grep "brd")" ]
	then
		sudo ./ramdisk_create_and_mount.sh -d >> "${LOG}" 2>&1
	fi

	# Create the new ramdisk
	local MEM=$(( RAMDISK * 1024 * 1024 ))
	sudo ./ramdisk_create_and_mount.sh -m ${MEM} -c >> "${LOG}" 2>&1

	cd - > /dev/null || exit

	cd "${RAMDISK_DIR}" || exit

	# Fill the ramdisk
	MEM=$(( RAMDISK * 1024 ))
	dd if=/dev/zero of=file.txt bs=1M count=${MEM} >> "${LOG}" 2>&1

	cd - > /dev/null || exit
}

##
# Function to kill the watch process
kill_watch() {
  pkill -f "watch -n 1" >> "${LOG}" 2>&1
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
	local exec_time minor_gc major_gc serdes
	local avg_exec_time=0 avg_minor_gc_time=0 avg_major_gc_time=0 avg_sd_time=0
	local other=0 max min max_index min_index sum

	cd "${bench_dir}" || exit

	for d in $(ls -l | grep '^d' | awk '{print $9}')
	do
		exec_time+=($(grep -w "TOTAL_TIME" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
		minor_gc+=($(grep -w "MINOR_GC" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
		major_gc+=($(grep -w "MAJOR_GC" ${d}/result.csv \
			| awk -F ',' '{if ($2 == "") print 0; else print $2}'))
		serdes+=($(grep -w "SERDES" ${d}/result.csv \
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
	unset 'serdes[$max_index]'
	unset 'serdes[$min_index]'

	sum=$(echo "scale=2; ${exec_time[@]/%/ +} 0" | bc -l)
	avg_exec_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)

	sum=$(echo "scale=2; ${minor_gc[@]/%/ +} 0" | bc -l)
	avg_minor_gc_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)

	sum=$(echo "scale=2; ${major_gc[@]/%/ +} 0" | bc -l)
	avg_major_gc_time=$(echo "scale=2; ${sum}/(${iter} - 2)" | bc -l)
	
	sum=$(echo "scale=2; ${serdes[@]/%/ +} 0" | bc -l)
	avg_sd_time=$(echo 'scale=2; x='$sum'/('$iter' - 2); if(x<1){"0"}; x' | bc -l)
	other=$(echo "scale=2; ${avg_exec_time} - ${avg_major_gc_time} - ${avg_minor_gc_time} - ${avg_sd_time}" | bc -l)

  {
    echo "---------,-------"
    echo "COMPONENT,TIME(s)"
    echo "---------,-------"
    echo "AVG_TOTAL_TIME,${avg_exec_time}"

    echo "AVG_OTHER,${other}"
    echo "AVG_MINOR_GC,${avg_minor_gc_time}"
    echo "AVG_MAJOR_GC,${avg_major_gc_time}"
    echo "AVG_SERDES,${avg_sd_time}"
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
    FORMATED="$(($ELAPSEDTIME / 3600))h:$(($ELAPSEDTIME % 3600 / 60))m:$(($ELAPSEDTIME % 60))s"  
    echo
    echo
    echo "    Benchmark Time Elapsed: $FORMATED"
    echo
    echo "============================================="
    echo
}

# Check if you have system_util. If not then download it
download_system_util() {
  if [ ! -d "system_util" ]
  then
    git clone git@github.com:jackkolokasis/system_util.git >> "${LOG}" 2>&1
  fi
}

# Check for the input arguments
while getopts ":n:o:m:tspkjfh" opt
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
      calculate_avg "${BENCH_DIR}" "${ITER}"
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
mkdir -p "${OUT}"

enable_perf_event

download_system_util

# Run each benchmark
for benchmark in "${BENCHMARKS[@]}"
do
  printStartMsg "${DEV_TH}" "${benchmark}"
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

			# Drop caches
			sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >> "${LOG}" 2>&1

      setup_cgroup

			# Prepare devices for Zookeeper and TeraCache accordingly
			###if [ $SERDES ]
			###then
			###	./dev_setup.sh
			###else
			###	./dev_setup.sh -t
			###fi

      clear_files
      create_files

			start_hadoop_yarn_zkeeper ${SERDES}
			
			update_conf "${benchmark}" ${SERDES}

			if [ -z "$JIT" ]
			then
				# Collect statics only for the garbage collector
				./jstat.sh "${RUN_DIR}" "${EXECUTORS}" 0 &
			else
				# Collect statics for garbage collector and JIT
				./jstat.sh "${RUN_DIR}" "${EXECUTORS}" 1 &
			fi

      # Monitor memory
      ./mem_usage.sh "${RUN_DIR}"/mem_usage.txt "${EXECUTORS}" &
			
			if [ $PERF_TOOL ]
			then
				# Count total cache references, misses and pagefaults
				./perf.sh "${RUN_DIR}"/perf.txt "${EXECUTORS}" &
			fi

			./serdes.sh "${RUN_DIR}"/serdes.txt "${EXECUTORS}" &
			
			# Enable profiler
			if [ ${PROFILER} ]
			then
				./profiler.sh "${RUN_DIR}"/profile.svg "${EXECUTORS}" &
			fi

      # System statistics start
      ./system_util/start_statistics.sh -d "${RUN_DIR}"

			cd "${BENCHMARK_SUITE}" || exit

			# Run benchmark and save output to tmp_out.txt
			#./bin/sh/run-benchmark.sh >> "${LOG}" 2>&1
			run_cgexec ./bin/sh/run-benchmark.sh >> "${LOG}" 2>&1

			cd - > /dev/null || exit

      # Kil watch process
      kill_watch
				
			if [ $PERF_TOOL ]
			then
				# Stop perf monitor
				stop_perf
			fi
            
            # System statistics stop
			./system_util/stop_statistics.sh -d "${RUN_DIR}"

			# Parse cpu and disk statistics results
			./system_util/extract-data.sh -r "${RUN_DIR}" -d ${DEV_TH} \
				-d ${DEV_HDFS} -d ${DEV_ZK} >> ${LOG} 2>&1

			# Copy the confifuration to the directory with the results
			cp ./conf.sh "${RUN_DIR}/"

			cp -r "$BENCHMARK_SUITE"/report/*-*-*-report-*/log/benchmark-summary.log "${RUN_DIR}/"
			cp -r "$BENCHMARK_SUITE"/report/bench.log "${RUN_DIR}/"
			cp -r "$BENCHMARK_SUITE"/report/teraHeap.txt "${RUN_DIR}/"

			rm -rf "${BENCHMARK_SUITE}"/report/*

			if [ $TH ]
			then
				./parse_results.sh -d "${RUN_DIR}" -t  >> "${LOG}" 2>&1
			else
				./parse_results.sh -d "${RUN_DIR}" >> "${LOG}" 2>&1
			fi

      # Plot the used memory and the buffer cache across the execution
      ./mem_usage.py -i "${RUN_DIR}"/mem_usage.txt \
        -o "${RUN_DIR}"/plots/mem_usage.png >> "${LOG}" 2>&1

      # The logs of the state machine are in the teraheap.txt
      if [ "$TH" ] && [ -f "${RUN_DIR}"/teraHeap.txt ]
      then
        if grep -q "STATE =" "${RUN_DIR}"/teraHeap.txt
        then
          grep "STATE =" teraHeap.txt | awk '{print $1,$4}' | awk 'BEGIN {FS="[: ]"; OFS=" "}
          {
            gsub(",", ".", $1)
            print $1","$3
          }' >> "${RUN_DIR}"/state_machine.csv

          ./state_machine.py -i "${RUN_DIR}"/state_machine.csv \
            -o "${RUN_DIR}"/plots/state_machine.png >> "${LOG}" 2>&1
        fi
      fi

			stop_hadoop_yarn_zkeeper

      clear_files

      delete_cgroup
		done

		if [ $ITER -ge 3 ]
		then
			# Calculate Average
			calculate_avg "${OUT}/${benchmark}/conf${i}" ${ITER}
		fi
	done

	ENDTIME=$(date +%s)
	printEndMsg "${STARTTIME}" "${ENDTIME}"
done

exit
