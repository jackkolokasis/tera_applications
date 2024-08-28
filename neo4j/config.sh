###################################################
#
# file: config.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-08-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Configurtion file for building Neo4j and benchmarks 
#
###################################################

TERAHEAP_JAVA=/home1/public/kolokasis/github/latest_version/teraheap/jdk17u067/build/linux-x86_64-server-release/jdk
COMMERCIAL_JAVA=/usr/lib/jvm/java-1.17.0-openjdk-amd64
TERAHEAP_REPO=/home1/public/kolokasis/github/latest_version/teraheap
TERA_APPS_REPO="/archive/users/kolokasis/tera_applications"
NEO4J_DIR="${TERA_APPS_REPO}/neo4j/neo4j"
NEO4J_EXEC_DIR="${NEO4J_DIR}/packaging/standalone/target/neo4j-community-5.15.0-SNAPSHOT/"
DATASET_DIR="/mnt/datasets/graphalytics"
COMPILE_OUT="${TERA_APPS_REPO}/neo4j/compile.out"

###################################################################
PROJECT_DIR=${TERAHEAP_REPO}

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
