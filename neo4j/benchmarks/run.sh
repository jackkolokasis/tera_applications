#!/usr/bin/env bash

# ./load-graph.sh \
#  --neo4j-home "/archive/users/kolokasis/tera_applications/neo4j/neo4j/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT" \
#  --input-vertex-path "/mnt/datasets/graphalytics/graphs/cit-Patents.v" \
#  --input-edge-path "/mnt/datasets/graphalytics/graphs/cit-Patents.e" \
#  --output-path "/mnt/spark/intermediate/cit-Patents" \
#  --weighted "false"

# cd "/mnt/spark/intermediate/cit-Patents" || exit
# mv database data
# cd - >/dev/null || exit 

CLASSPATH="$(find ../neo4j -name "*.jar" | xargs readlink -f | paste -sd ':')"
CLASSPATH+=":/archive/users/kolokasis/tera_applications/neo4j/neo4j-graph-data-science-2.6.0.jar"
CLASSPATH+=":./target/gds-benchmarks-1.0-SNAPSHOT.jar"

PROJECT_DIR="/home1/public/kolokasis/github/latest_version/teraheap"

export LIBRARY_PATH=${PROJECT_DIR}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${PROJECT_DIR}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${PROJECT_DIR}/allocator/include:$PATH
export C_INCLUDE_PATH=${PROJECT_DIR}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${PROJECT_DIR}/allocator/include:$CPLUS_INCLUDE_PATH
export ALLOCATOR_HOME=${PROJECT_DIR}/allocator

export LIBRARY_PATH=${PROJECT_DIR}/tera_malloc/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${PROJECT_DIR}/tera_malloc/lib:$LD_LIBRARY_PATH
export PATH=${PROJECT_DIR}/tera_malloc/include:$PATH
export C_INCLUDE_PATH=${PROJECT_DIR}/tera_malloc/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${PROJECT_DIR}/tera_malloc/include:$CPLUS_INCLUDE_PATH
export TERA_MALLOC_HOME=${PROJECT_DIR}/tera_malloc
  
JAVA_HOME="/home1/public/kolokasis/github/latest_version/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
${JAVA_HOME}/bin/java \
  -cp ${CLASSPATH} \
  com.algolib.BenchmarkRunner \
  --algo sssp \
  --database_path "/mnt/spark/intermediate/cit-Patents"