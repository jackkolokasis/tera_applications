#!/usr/bin/env bash

CPU_ARCH=$(uname -p)
USER=$(whoami)
TERAHEAP_REPO=$HOME/teraheap

# Export Allocator
export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$CPLUS_INCLUDE_PATH

# Set JAVA_HOME to use TeraHeap openjdk 8 JVM for Spark compilation
#export JAVA_HOME="${TERAHEAP_REPO}/jdk17u067/build/linux-$CPU_ARCH-server-release/jdk"
export JAVA_HOME="${TERAHEAP_REPO}/jdk8u345/build/linux-$CPU_ARCH-normal-server-release/jdk"
#export JAVA_HOME=/spare/$USER/openjdk/jdk8u402-b06
# Set up the path of TeraHeap applications
TERA_APPS_REPO=$HOME/tera_applications
echo "TERA_APPS_REPO="$TERA_APPS_REPO
SPARK_VERSION="spark-3.3.0"
#
########################################
# DO NOT CHANGE THE FOLLOWING VARIABLES
########################################
SPARK_DIR="${TERA_APPS_REPO}/spark/${SPARK_VERSION}"
echo "SPARK_DIR="$SPARK_DIR
COMPILE_OUT="${TERA_APPS_REPO}/spark/compile.out"
