#!/usr/bin/env bash

TERAHEAP_REPO="/home1/public/kolokasis/jdk8u/teracache"

# Export Allocator
export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib/:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include/:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include/:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include/:$CPLUS_INCLUDE_PATH

# Set JAVA_HOME to use TeraHeap JVM
export JAVA_HOME="${TERAHEAP_REPO}/jdk8u345/build/linux-x86_64-normal-server-release/jdk"
# Set up the path of TeraHeap applications
TERA_APPS_REPO="/opt/kolokasis/tera_applications"
SPARK_VERSION="spark-3.3.0"
#
########################################
# DO NOT CHANGE THE FOLLOWING VARIABLES
########################################
SPARK_DIR="${TERA_APPS_REPO}/spark/${SPARK_VERSION}"
COMPILE_OUT="${TERA_APPS_REPO}/spark/compile.out"
