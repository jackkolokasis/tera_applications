#!/usr/bin/env bash

CPU_ARCH=$(uname -p)
USER=$(whoami)
TERAHEAP_HOME=/spare/perpap/teraheap

# Export Allocator
export LIBRARY_PATH=${TERAHEAP_HOME}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_HOME}/allocator/lib:$LD_LIBRARY_PATH
# Set JAVA_HOME to use TeraHeap openjdk 8 JVM for Spark compilation
#export JAVA_HOME="${TERAHEAP_HOME}/jdk17u067/build/linux-$CPU_ARCH-server-release/jdk"
export JAVA_HOME="${TERAHEAP_HOME}/jdk8u345/build/linux-$CPU_ARCH-normal-server-release/jdk"

# Set up the path of TeraHeap applications
TERA_APPS_HOME="$(pwd)/.."
SPARK_VERSION="spark-3.3.0"
#
########################################
# DO NOT CHANGE THE FOLLOWING VARIABLES
########################################
SPARK_DIR="${TERA_APPS_HOME}/spark/${SPARK_VERSION}"
COMPILE_OUT="${TERA_APPS_HOME}/spark/compile.out"
