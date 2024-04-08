#!/usr/bin/env bash

###################################################
#
# file: update_conf.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  04-05-2024 
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
    echo -n "      $0 [option ...] [-b-h]"
    echo
    echo "Options:"
    echo "      -b  Custom Benchmark"
    echo "      -h  Show usage"
    echo

    exit 1
}

update_slave_file() {
  if [ "$SPARK_VERSION" == "2.3.0" ]
  then
    echo "${SPARK_SLAVE}" > slaves
  else
    echo "${SPARK_SLAVE}" > workers
  fi
}

update_spark_env() {
  # Update JAVA_HOME
  sed -i '/JAVA_HOME/c\JAVA_HOME='"${MY_JAVA_HOME}" spark-env.sh
  SPARK_WORKER_MEMORY=$(( H1_SIZE * NUM_EXECUTORS ))
  SPARK_WORKER_CORES=$(( EXEC_CORES * NUM_EXECUTORS ))
  # Change the worker cores
  sed -i '/SPARK_WORKER_CORES/c\SPARK_WORKER_CORES='"${SPARK_WORKER_CORES}" spark-env.sh
  # Change the worker memory
  sed -i '/SPARK_WORKER_MEMORY/c\SPARK_WORKER_MEMORY='"${SPARK_WORKER_MEMORY}"'g' spark-env.sh
  # Change the worker memory
  sed -i '/SPARK_LOCAL_DIRS/c\SPARK_LOCAL_DIRS='"${MNT_SHFL}" spark-env.sh
  # Change the master IP
  sed -i '/SPARK_MASTER_IP/c\SPARK_MASTER_IP=spark:\/\/'"${SPARK_MASTER}"':7077' spark-env.sh
  # Change the master host
  sed -i '/SPARK_MASTER_HOST/c\SPARK_MASTER_HOST='"${SPARK_MASTER}" spark-env.sh
  # Change the master host
  sed -i '/SPARK_LOCAL_IP/c\SPARK_LOCAL_IP='"${SPARK_SLAVE}" spark-env.sh
}

update_spark_defaults() {
  local extra_java_opts="spark.executor.extraJavaOptions -server "
  extra_java_opts+="-XX:-ClassUnloading -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_THREADS} "
  extra_java_opts+="-XX:-ResizeTLAB -XX:-UseCompressedOops -XX:-UseCompressedClassPointers "
  extra_java_opts+=${USER_EXTRA_JAVA_OPTS}

  # Change the spark.log.dir
  sed -i '/eventLog.dir/c\spark.eventLog.dir '"${MASTER_LOG_DIR}" spark-defaults.conf
  # Change the spark.metrics.conf
  sed -i '/spark.metrics.conf/c\spark.metrics.conf '"${MASTER_METRIC_FILE}" spark-defaults.conf
  # Change the spark.executor.extraJavaOptions
  sed -i '/^spark\.executor\.extraJavaOptions/s/.*/'"${extra_java_opts}"'/' spark-defaults.conf
  # Change the spark.memory.storageFraction
  sed -i '/storageFraction/c\spark.memory.storageFraction '"${MEM_FRACTION}" spark-defaults.conf
}

update_spark_bench() {
	sed -i '/master="[a-z0-9-]*"/c\master='"\"${SPARK_MASTER}\"" env.sh
	sed -i '/MC_LIST/c\MC_LIST='"\"${SPARK_SLAVE}\"" env.sh
  sed -i '/DATA_HDFS=file/c\DATA_HDFS='"${DATA_HDFS}" env.sh
  sed -i "s|export SPARK_HOME=.*$|export SPARK_HOME=${SPARK_DIR}|g" env.sh
	sed -i '/SPARK_EXECUTOR_MEMORY/c\SPARK_EXECUTOR_MEMORY='"${H1_SIZE}"'g' env.sh
	sed -i '/SPARK_EXECUTOR_CORES/c\SPARK_EXECUTOR_CORES='"${EXEC_CORES}" env.sh
	sed -i '/SPARK_EXECUTOR_INSTANCES/c\SPARK_EXECUTOR_INSTANCES='"${NUM_EXECUTORS}" env.sh
	sed -i '/STORAGE_LEVEL/c\STORAGE_LEVEL='"${S_LEVEL}" env.sh
	sed -i '/NUM_OF_PARTITIONS/c\NUM_OF_PARTITIONS='"${NUM_OF_PARTITIONS}" env.sh
}

# Check for the input arguments
while getopts ":b:h" opt
do
    case "${opt}" in
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
cd "${SPARK_DIR}"/conf || exit
update_slave_file
update_spark_env
update_spark_defaults
cd - > /dev/null || exit

if [ "${CUSTOM_BENCHMARK}" == "false" ]
then
	# Enter the spark-bechmarks
	cd "${SPARK_BENCH_DIR}"/conf/ || exit

  update_spark_bench

	cd - > /dev/null || exit

  # Copy configuration of the workload
  cp "./configs/workloads/${DATA_SIZE}/${BENCHMARKS}/env.sh" \
    "${SPARK_BENCH_DIR}/${BENCHMARKS}/conf"

	cd - > /dev/null || exit
fi

exit
