#!/usr/bin/env bash

###################################################
#
# file: run_benchmark.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  27-07-2024
# @email:    kolokasis@ics.forth.gr
#
###################################################

. ./conf.sh

RUN_DIR=$1
QUERY=$2
SETUP=$3

CLASSPATH=""
JAVA_OPTS=""

# Set the classpath
set_class_path() {
  local jar_files=""

  cd ${BENCH_DIR}/lucene/lucene9.6.0 

  # Append jar files
  for j in $(find "$(pwd)" -name "*.jar"); do
    if [ -z "$jar_files" ]; then
      jar_files="$j"
    else
      jar_files="$jar_files:$j"
    fi
  done

  CLASSPATH=${jar_files}:${BENCH_DIR}/lucene/benchmarks/out

  cd - > /dev/null || exit
}

run_m1() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_ML_LS_HL_MS \
    -n 50 \
    -nq 50000 -nq 7000 -nq 500000 -nq 400 -nq 80000 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m2() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_HL \
    -n 50 \
    -nq 50000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m3() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS_ML \
    -n 50 \
    -nq 80000 -nq 7000 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m4() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 50000 -nq 7400 -nq 0 -nq 0 -nq 0 \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m5() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 80000 -nq 7400 \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m6() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 500000 -nq 7400 \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

export_env_variables() {
  export JAVA_HOME=${JAVA_PATH}
  export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
  export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LD_LIBRARY_PATH
  export PATH=${TERAHEAP_REPO}/allocator/include/:$PATH
  export LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LIBRARY_PATH
  export LD_LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LD_LIBRARY_PATH
  export PATH=${TERAHEAP_REPO}/tera_malloc/include/:$PATH
}

set_java_opts() {
  case "$SETUP" in
    "NATIVE")
      # These are the runtime arguments for runs with vanilla JVM
      JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers \
        -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_THREADS} -XX:+AlwaysPreTouch \
        -Xmx${H1_SIZE}g -Xms${H1_SIZE}g"
      ;;
    "FLEXHEAP")
      # These are the runtime arguments for running with FlexHeap
      MEM_VALUE=$(echo $MEM_BUDGET | grep -oP '\d+')
      MEM_UNIT=$(echo $MEM_BUDGET | grep -oP '[A-Za-z]+')

      # Convert to bytes (assuming the unit is 'G' for gigabytes)
      if [ "$MEM_UNIT" == "G" ]; then
        DRAMLIMIT=$((MEM_VALUE * 1024 * 1024 * 1024))
      else
        DRAMLIMIT=$((MEM_VALUE * 1024 * 1024))
      fi

      JAVA_OPTS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers \
        -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_THREADS} -XX:+EnableFlexHeap \
        -XX:FlexResizingPolicy=2 -XX:+ShowMessageBoxOnError \
        -XX:FlexDRAMLimit=${DRAMLIMIT} -Xmx${H1_SIZE}g "
      ;;
    "TERAHEAP")
      # These are the runtime arguments for running with TeraHeap
      tc_size=$(( (900 - H1_SIZE) * 1024 * 1024 * 1024 ))
      h2_file_size=$((H2_FILE_SZ * 1024 * 1024 * 1024))

      JAVA_OPTS="-XX:-ClassUnloading -XX:+UseParallelGC -XX:ParallelGCThreads=${GC_THREADS} -XX:+EnableTeraHeap \
        -XX:TeraHeapSize=${tc_size} -Xmx=900g -Xms${H1_SIZE}g -XX:-UseCompressedOops -XX:-UseCompressedClassPointers \
        -XX:+TeraHeapStatistics -Xlogth:teraHeap.txt -XX:TeraHeapPolicy="DefaultPolicy" -XX:TeraStripeSize=${STRIPE_SIZE} \
        -XX:+ShowMessageBoxOnError -XX:AllocateH2At="${MNT_H2}/" -XX:H2FileSize=${h2_file_size} -XX:TeraCPUStatsPolicy=${CPU_STATS_POLICY}"
      ;;
  esac
}

cd ${BENCH_DIR}/lucene/benchmarks || exit

export_env_variables
set_class_path
set_java_opts

case "$QUERY" in
  M1)
    run_m1
    ;;
  M2)
    run_m2
    ;;
  M3)
    run_m3
    ;;
  M4)
    run_m4
    ;;
  M5)
    run_m5
    ;;
  M6)
    run_m6
    ;;
esac

cd - > /dev/null || exit
