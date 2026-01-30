#!/usr/bin/env bash

RESULT_DIR=$1

TERAHEAP_REPO="/home1/public/kolokasis/github/latest_version/teraheap"

export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$CPLUS_INCLUDE_PATH

export LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/tera_malloc/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/tera_malloc/include:$CPLUS_INCLUDE_PATH

JAVA_HOME="/home1/public/kolokasis/github/latest_version/teraheap/jdk17u067/build/linux-x86_64-server-fastdebug/jdk"
BENCHMARKS=( "avrora" "batik" "biojava" "eclipse" "fop" "graphchi" "jme" "jython" "kafka" "luindex" "lusearch" "pmd" "sunflow" "xalan" "zxing" )

run_benchmark() {
    local benchmark=$1
    local java_opts="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers -XX:+UseParallelGC -Xms4g -Xmx4g"
    java_opts+=" -XX:+ShowMessageBoxOnError"

    mkdir -p "${RESULT_DIR}"

    echo "Starting benchmark: $benchmark"

    # Launch the benchmark in the background
    ${JAVA_HOME}/bin/java $java_opts \
      -jar dacapo-23.11-chopin.jar \
      -s "large" "$benchmark" \
      > "${RESULT_DIR}/${benchmark}_out.txt" 2> "${RESULT_DIR}/${benchmark}_err.txt"

    echo "Finished benchmark: $benchmark"
}

for b in "${BENCHMARKS[@]}"
do
  ./monitor_perf_warnings.sh ${RESULT_DIR}/${b}_perf_warnings.txt &
  run_benchmark ${b}
done
