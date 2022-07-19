#!/usr/bin/env bash

###################################################
#
# file: update_conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  27-02-2021 
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to setup the configuration for experiments
#
###################################################

. ./conf.sh

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-k][-h]"
    echo
    echo "Options:"
    echo "      -i  Index"
    echo "      -b  Custom Benchmark"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Check for the input arguments
while getopts ":i:bh" opt
do
    case "${opt}" in
        i)
            INDEX=${OPTARG}
            ;;
        b)
            CUSTOM_BENCHMARK=${OPTARG}
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# Enter to spark configuration
cd ${SPARK_DIR}/conf

# Change the worker cores
sed -i '/SPARK_WORKER_CORES/c\SPARK_WORKER_CORES='"${CORES}" spark-env.sh

# Change the worker memory
sed -i '/SPARK_WORKER_MEMORY/c\SPARK_WORKER_MEMORY='"${MIN_HEAP}"'g' spark-env.sh

# Change the worker memory
sed -i '/SPARK_LOCAL_DIRS/c\SPARK_LOCAL_DIRS='"${MNT_SHFL}" spark-env.sh

# Change the master IP
sed -i '/SPARK_MASTER_IP/c\SPARK_MASTER_IP=spark:\/\/'"${SPARK_MASTER}"':7077' spark-env.sh

# Change the master host
sed -i '/SPARK_MASTER_HOST/c\SPARK_MASTER_HOST='"${SPARK_MASTER}" spark-env.sh

# Change the master host
sed -i '/SPARK_LOCAL_IP/c\SPARK_LOCAL_IP='"${SPARK_SLAVE}" spark-env.sh

# Change the spark.memory.storageFraction
sed -i '/storageFraction/c\spark.memory.storageFraction '"${MEM_FRACTION}" spark-defaults.conf

# Change the spark.log.dir
sed -i '/eventLog/c\spark.eventLog.dir '"${MASTER_LOG_DIR}" spark-defaults.conf

# Change the spark.metrics.conf
sed -i '/metrics/c\spark.metrics.conf '"${MASTER_METRIC_FILE}" spark-defaults.conf

# Change GC threads
sed -i "s/ParallelGCThreads=[0-9]*/ParallelGCThreads=${GC_THREADS}/g" spark-defaults.conf

cd - >> ${BENCH_LOG} 2>&1

if [ $CUSTOM_BENCHMARK == "false" ]
then
	# Enter the spark-bechmarks
	cd ${SPARK_BENCH_DIR}/conf/

  # Master node
	sed -i '/master/c\master='"${SPARK_MASTER}" env.sh
  
  # Slave node
	sed -i '/MC_LIST/c\MC_LIST='"${SPARK_SLAVE}" env.sh
  
  # Slave node
	sed -i '/DATA_HDFS/c\DATA_HDFS='"${DATA_HDFS}" env.sh

	# Change spark benchmarks configuration execur memory
	sed -i '/SPARK_EXECUTOR_MEMORY/c\SPARK_EXECUTOR_MEMORY='"${HEAP[$INDEX]}"'g' env.sh

	# Change spark benchmarks configuration executor core
	sed -i '/SPARK_EXECUTOR_CORES/c\SPARK_EXECUTOR_CORES='"${EXEC_CORES[$INDEX]}" env.sh

	# Change storage level
	sed -i '/STORAGE_LEVEL/c\STORAGE_LEVEL='"${S_LEVEL[$INDEX]}" env.sh

	cd - >> ${BENCH_LOG} 2>&1
fi

if [ ${RAMDISK[${INDEX}]} -ne 0 ]
then
  cp ./ramdisk_create_and_mount.sh /tmp

	cd /tmp

	# Remove the previous ramdisk
	sudo ./ramdisk_create_and_mount.sh -d >> ${BENCH_LOG} 2>&1

	# Create the new ramdisk
	MEM=$(( ${RAMDISK[$INDEX]} * 1024 * 1024 ))
	sudo ./ramdisk_create_and_mount.sh -m ${MEM} -c >> ${BENCH_LOG} 2>&1

  cd - >> ${BENCH_LOG} 2>&1

	cd /mnt/ramdisk

	# Fill the ramdisk
	MEM=$(( ${RAMDISK[$INDEX]} * 1024 ))
	dd if=/dev/zero of=file.txt bs=1M count=${MEM} >> ${BENCH_LOG} 2>&1

	cd - >> ${BENCH_LOG} 2>&1
fi

exit
