#!/usr/bin/env bash

JAVA_HOME=/spare/perpap/teraheap/jdk17u067/build/linux-aarch64-server-release/jdk
SPARK_WORKER_CORES=8
SPARK_WORKER_INSTANCES=1
SPARK_WORKER_MEMORY=38g
SPARK_LOCAL_DIRS=/mnt/spark
SPARK_MASTER_IP=spark://ampere:7077
SPARK_MASTER_HOST=ampere
SPARK_LOCAL_IP=ampere
