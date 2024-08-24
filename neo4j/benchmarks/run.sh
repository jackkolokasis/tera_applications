#!/usr/bin/env bash

#./load-graph.sh \
#  --neo4j-home "/archive/users/kolokasis/tera_applications/neo4j/neo4j/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT" \
#  --input-vertex-path "/mnt/datasets/graphalytics/graphs/cit-Patents.v" \
#  --input-edge-path "/mnt/datasets/graphalytics/graphs/cit-Patents.e" \
#  --output-path "/mnt/spark/intermediate/cit-Patents" \
#  --weighted "false"
#
#exit

CLASSPATH="$(find ../neo4j -name "*.jar" | xargs readlink -f | paste -sd ':')"
#GDS="$(find ~/.m2/repository/org/neo4j/gds/*/2.6.0 -name "*.jar" | paste -sd ':')"
#CLASSPATH+="${GDS}"
#CLASSPATH+=":/home1/public/kolokasis/.m2/repository/org/neo4j/gds/algo/2.6.0/algo-2.6.0.jar"
##CLASSPATH+=":/home1/public/kolokasis/.m2/repository/org/neo4j/gds/proc/2.6.0/proc-2.6.0.jar"
##CLASSPATH+=":/home1/public/kolokasis/.m2/repository/org/neo4j/gds/core/2.6.0/core-2.6.0.jar"
##CLASSPATH+=":/home1/public/kolokasis/.m2/repository/org/neo4j/gds/proc-centrality/2.6.0/proc-centrality-2.6.0.jar"
##CLASSPATH+=":/home1/public/kolokasis/.m2/repository/org/neo4j/gds/opengds-procedure-facade/2.6.0/opengds-procedure-facade-2.6.0.jar"
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
  
#-cp ./target/gds-benchmarks-1.0-SNAPSHOT-jar-with-dependencies.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/community/configuration/target/neo4j-configuration-5.15.0-SNAPSHOT.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/community/ssl/target/neo4j-ssl-5.15.0-SNAPSHOT.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/community/fulltext-index/target/neo4j-fulltext-index-5.15.0-SNAPSHOT.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT/lib/log4j-core-2.20.0.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT/lib/log4j-api-2.20.0.jar:/archive/users/kolokasis/tera_applications/neo4j/neo4j/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT/lib/log4j-layout-template-json-2.20.0.jar \

JAVA_HOME="/home1/public/kolokasis/github/latest_version/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
${JAVA_HOME}/bin/java \
  -cp ${CLASSPATH} \
  com.algolib.PageRankBenchmark

#JAVA_HOME="/home1/public/kolokasis/github/latest_version/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk"
#JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"

#${JAVA_HOME}/bin/java \
#  -jar ./target/gds-benchmarks-1.0-SNAPSHOT.jar
