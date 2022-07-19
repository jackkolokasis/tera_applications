#!/usr/bin/env bash

###################################################
#
# file: update_conf_tc.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  27-02-2021 
# @email:    kolokasis@ics.forth.gr
#
# Scrpt to setup the configuration for experiments
# for teracache
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
    echo "      -i  Minimum Heap Size"
    echo "      -b  Custom Benchmark"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Check for the input arguments
while getopts ":i:b:h" opt
do
    case "${opt}" in
        m)
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
sed -i '/SPARK_WORKER_CORES/c\SPARK_WORKER_CORES='"${EXEC_CORES[$INDEX]}" spark-env.sh

# Change the worker memory
sed -i '/SPARK_WORKER_MEMORY/c\SPARK_WORKER_MEMORY='"${TERACACHE[$INDEX]}"'g' spark-env.sh

# Change the worker memory
sed -i '/SPARK_LOCAL_DIRS/c\SPARK_LOCAL_DIRS='"${MNT_SHFL}" spark-env.sh

# Change the master IP
sed -i '/SPARK_MASTER_IP/c\SPARK_MASTER_IP=spark:\/\/'"${SPARK_MASTER}"':7077' spark-env.sh

# Change the master host
sed -i '/SPARK_MASTER_HOST/c\SPARK_MASTER_HOST='"${SPARK_MASTER}" spark-env.sh

# Change the master host
sed -i '/SPARK_LOCAL_IP/c\SPARK_LOCAL_IP='"${SPARK_SLAVE}" spark-env.sh

# Change the spark.log.dir
sed -i '/eventLog/c\spark.eventLog.dir '"${MASTER_LOG_DIR}" spark-defaults.conf

# Change the spark.metrics.conf
sed -i '/metrics/c\spark.metrics.conf '"${MASTER_METRIC_FILE}" spark-defaults.conf

# Change GC threads
sed -i "s/ParallelGCThreads=[0-9]*/ParallelGCThreads=${GC_THREADS}/g" spark-defaults.conf

# Change the minimum heap size
# Change only the first -Xms 
sed -i -e '0,/-Xms[0-9]*g/ s/-Xms[0-9]*g/-Xms'"${HEAP[$INDEX]}"'g/' spark-defaults.conf

# Change the value of the size of New Generation '-Xmn'. If the value is:
# NEW_GEN == 0: Do not set the size of the young gen. Let the default
# NEW_GEN > 0 : Set the size of the young gen to the 'NEW_GEN' value
if [ ${NEW_GEN[$INDEX]} -eq 0 ]
then
	sed -i -e '0,/-Xmn[0-9]*g/ s/-Xmn[0-9]*g //' spark-defaults.conf
else
	sed -i -e '0,/-Xmn[0-9]*g/ s/-Xmn[0-9]*g //' spark-defaults.conf
	sed -i -e '0,/-Xms[0-9]*g/ s/-Xms[0-9]*g/& -Xmn'"${NEW_GEN[$INDEX]}"'g/' spark-defaults.conf
fi

# Change teracache size for Spark
sed -i '/teracache.heap.size/c\spark.teracache.heap.size '"${TERACACHE[$INDEX]}"'g' spark-defaults.conf

TC_BYTES=$(echo "(${TERACACHE[$INDEX]} - ${HEAP[$INDEX]}) * 1024 * 1024 * 1024" | bc)

# Change teracache size for JVM
sed -i "s/TeraCacheSize=[0-9]*/TeraCacheSize=${TC_BYTES}/g" spark-defaults.conf

# Change the spark.memory.fraction
sed -i '/storageFraction/c\spark.memory.storageFraction '"${MEM_FRACTION[$INDEX]}" spark-defaults.conf

cd - >> ${BENCH_LOG} 2>&1

if [ ${CUSTOM_BENCHMARK} == "false" ]
then
	# Enter the spark-bechmarks
	cd ${SPARK_BENCH_DIR}/conf/

	# Change spark benchmarks configuration
	sed -i '/SPARK_EXECUTOR_MEMORY/c\SPARK_EXECUTOR_MEMORY='"${TERACACHE[$INDEX]}"'g' env.sh

	# Change spark benchmarks configuration executor core
	sed -i '/SPARK_EXECUTOR_CORES/c\SPARK_EXECUTOR_CORES='"${EXEC_CORES[$INDEX]}" env.sh

	# Change storage level
	sed -i '/STORAGE_LEVEL/c\STORAGE_LEVEL='"${S_LEVEL[$INDEX]}" env.sh

	cd - >> ${BENCH_LOG} 2>&1
fi

if [ ${RAMDISK[$INDEX]} -ne 0 ]
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
