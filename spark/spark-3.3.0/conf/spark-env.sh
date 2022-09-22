#!/usr/bin/env bash

JAVA_HOME=/home1/public/kolokasis/jdk8u/teracache/jdk8u345/build/linux-x86_64-normal-server-release/jdk
SPARK_WORKER_CORES=16
SPARK_WORKER_INSTANCES=1
SPARK_WORKER_MEMORY=1200g
SPARK_LOCAL_DIRS=/mnt/spark
SPARK_MASTER_IP=spark://sith4-fast:7077
SPARK_MASTER_HOST=sith4-fast
SPARK_LOCAL_IP=sith4-fast
SPARK_DAEMON_JAVA_OPTS=-XX:-UseParallelOldGC
