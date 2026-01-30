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
  case "$CACHE" in
    "ENABLE")
      ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
        EvaluateQueriesCacheEnable \
        -i "${DATASET}" \
        -q ${QUERIES_DIR}/HS_ML_LS_HL_MS \
        -n 50 \
        -nq 50000 -nq 7000 -nq 500000 -nq 400 -nq 80000 \
        -r /tmp/queries.txt \
        -c ${QUERY_CACHE} \
        -e ${CACHE_ENTRIES} \
        > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
        # ^
        # -microFGC \
    ;;
    "DISABLE")
      ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
        EvaluateQueries \
        -i "${DATASET}" \
        -q ${QUERIES_DIR}/HS_ML_LS_HL_MS \
        -n 50 \
        -nq 50000 -nq 7000 -nq 500000 -nq 400 -nq 80000 \
        -r /tmp/queries.txt \
        > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
    ;;
  esac
}

run_m2() {
	case "$CACHE" in
    "ENABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
   EvaluateQueriesCacheEnable \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_HL \
    -n 50 \
    -nq 50000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
     "DISABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_HL \
    -n 50 \
    -nq 50000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
	esac
}

run_m3() {
	case "$CACHE" in
    "ENABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
   EvaluateQueriesCacheEnable \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS_ML \
    -n 50 \
    -nq 80000 -nq 7000 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
     "DISABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS_ML \
    -n 50 \
    -nq 80000 -nq 7000 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
	esac
}

run_m4() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 50000 -nq 7400 -nq 0 -nq 0 -nq 0 \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m5() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 80000 -nq 7400 \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m6() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 500000 -nq 7400 \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m7() {
	case "$CACHE" in
    "ENABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
   EvaluateQueriesCacheEnable \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS \
    -n 50 \
    -nq 500000 -nq 0 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
     "DISABLE")
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS \
    -n 50 \
    -nq 500000 -nq 0 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
      ;;
	esac
}

run_m8() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HL \
    -n 50 \
    -nq 7000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m9() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_HL \
    -n 50 \
    -nq 50000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m10() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HS_LS_HL \
    -n 50 \
    -nq 7000 -nq 50000 -nq 500000 -nq 400 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

run_m11() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HL \
    -n 50 \
    -nq 7000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

run_m12() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_LS \
    -n 50 \
    -nq 50000 -nq 500000 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

# For benchmarks
run_m15() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS -q ${QUERIES_DIR}/MS -q ${QUERIES_DIR}/HS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 50 -n 50 -n 500000 \
    -nq 500000 -nq 80000 -nq 50000 -nq 7400 \
    -c ${QUERY_CACHE} \
    -e ${CACHE_ENTRIES}\
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m7() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS \
    -n 50 \
    -nq 500000 -nq 0 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m8() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HL \
    -n 50 \
    -nq 7000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m9() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_HL \
    -n 50 \
    -nq 50000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m10() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HS_LS_HL \
    -n 50 \
    -nq 7000 -nq 50000 -nq 500000 -nq 400 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

run_m11() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/ML_HL \
    -n 50 \
    -nq 7000 -nq 400 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

run_m12() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueriesPerPhase \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS_LS \
    -n 50 \
    -nq 50000 -nq 500000 -nq 0 -nq 0 -nq 0 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
  }

# For benchmarks
run_m15() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/LS -q ${QUERIES_DIR}/MS -q ${QUERIES_DIR}/HS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 50 -n 50 -n 500000 \
    -nq 500000 -nq 80000 -nq 50000 -nq 7400 \
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
  export LD_LIBRARY_PATH=/home1/public/$(whoami)/hsdis/build/linux-amd64/:$LD_LIBRARY_PATH
}

set_java_opts() {
  case "$SETUP" in
    "NATIVE")
      JAVA_OPTS="-XX:-ClassUnloading -XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:-ResizePLAB \
        -XX:+UseG1GC -XX:ParallelGCThreads=${GC_THREADS} \
        -Xlog:gc*:file=\"${RUN_DIR}/gc.log\" \
        -XX:MaxGCPauseMillis=400 \
        -Xmx${H1_SIZE}g -Xms${H1_SIZE}g"
      ;;
    "TERAHEAP")
      # These are the runtime arguments for running with TeraHeap
      tc_size=$(( (800 - H1_SIZE) * 1024 * 1024 * 1024 ))
      local H2_FILE_SZ_BYTES=$(echo "${H2_FILE_SZ} * 1024 * 1024 * 1024" | bc)
      local H2_PATH="${MNT_H2}/"

      JAVA_OPTS="-XX:-ClassUnloading -XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:-ResizePLAB \
        -XX:+EnableTeraHeap \
        -XX:AllocateH2At=${H2_PATH} -XX:H2FileSize=${H2_FILE_SZ_BYTES} \
        -XX:+UseG1GC -XX:ParallelGCThreads=${GC_THREADS} \
        -XX:TeraStripeSize=${STRIPE_SIZE} \
        -Xlog:gc*:file=\"${RUN_DIR}/gc.log\" \
        -Xmx800g \
        -XX:TeraHeapSize=${tc_size} \
        -Xms${H1_SIZE}g \
        -XX:MaxGCPauseMillis=400 \
        -XX:+TeraHeapStatistics -Xlogth:teraHeap.txt "
        # Additional flags occasionally useful:
        # -XX:G1PeriodicGCInterval=10000 -XX:-G1PeriodicGCInvokesConcurrent \
        # -XX:+ShowMessageBoxOnError \
        # -XX:NativeMemoryTracking=detail \
        # -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly \
        # -XX:MaxGCPauseMillis=10000 \
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
  M7)
    run_m7
    ;;
  M8)
    run_m8
    ;;
  M9)
    run_m9
    ;;
  M10)
    run_m10
    ;;
  M11)
    run_m11
    ;;
  M12)
    run_m12
    ;;
esac

if [ $SETUP == "TERAHEAP" ]; then
  mv teraHeap.txt ${RUN_DIR}/teraheap.txt
fi

cd - > /dev/null || exit

