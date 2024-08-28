#!/usr/bin/env bash

. ../scripts/conf.sh

RUN_DIR=$1
WORKLOAD=$2

CLASSPATH="$(find ../neo4j -name "*.jar" | xargs readlink -f | paste -sd ':')"
CLASSPATH+=":${BENCH_DIR}/neo4j/graph-data-science/build/distributions/open-gds-2.6.0.jar"
CLASSPATH+=":./target/gds-benchmarks-1.0-SNAPSHOT.jar"

export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$CPLUS_INCLUDE_PATH
export ALLOCATOR_HOME=${TERAHEAP_REPO}/allocator

export LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/tera_malloc/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/tera_malloc/include:$CPLUS_INCLUDE_PATH
export TERA_MALLOC_HOME=${TERAHEAP_REPO}/tera_malloc

JAVA_HOME="${TERAHEAP_REPO}/jdk17u067/build/linux-x86_64-server-release/jdk"

teraheap_size=$(((1200 - H1) * 1024 * 1024 * 1024))
h2_file_size=$(( H2_FILE_SZ * 1024 * 1024 * 1024 ))

OPTS="-XX:+UseParallelGC -XX:ParallelGCThreads=${GC_THREADS} -XX:+EnableTeraHeap -XX:TeraHeapPolicy=${TERAHEAP_POLICY} "
OPTS+="-XX:TeraHeapSize=${teraheap_size} -Xmx1200g -Xms${H1}g -XX:-UseCompressedOops "
OPTS+="-XX:-UseCompressedClassPointers -XX:+TeraHeapStatistics -XX:-UseParallelH2Allocator -XX:TeraStripeSize=${STRIPE_SIZE} "
OPTS+="-XX:AllocateH2At=${MNT_H2}/ -XX:+ShowMessageBoxOnError "
OPTS+="-XX:H2FileSize=${h2_file_size} -Xlogth:teraHeap.txt"
  
${JAVA_HOME}/bin/java ${OPTS} \
  -cp ${CLASSPATH} \
  com.algolib.BenchmarkRunner \
  --algo "$WORKLOAD" \
  --database_path "${MNT_DATABASE}/intermediate/${GRAPH_NAME}" > "${RUN_DIR}/tmp.out"
