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

CLASSPATH=""

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
    -nq 50000 -nq 400 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m3() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    EvaluateQueries \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/MS_ML \
    -n 50 \
    -nq 80000 -nq 7000 \
    -r /tmp/queries.txt \
    > "${RUN_DIR}"/tmp.out 2> "${RUN_DIR}"/tmp.err
}

run_m4() {
  ${JAVA_PATH}/bin/java -cp "${CLASSPATH}" ${JAVA_OPTS} \
    MultiTenantEvaluateQueriesWithBatching \
    -i "${DATASET}" \
    -q ${QUERIES_DIR}/HS -q ${QUERIES_DIR}/ML_HL \
    -n 50 -n 500000 \
    -nq 50000 -nq 7400 \
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

cd ${BENCH_DIR}/lucene/benchmarks || exit

export_env_variables
set_class_path

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
