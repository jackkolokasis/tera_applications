#!/usr/bin/env bash

LOGIN=$(whoami)

export JAVA_HOME="/home1/public/${LOGIN}/work/teraheap/jdk17/build/linux-x86_64-server-release/jdk"
TERA_APPS_REPO="/home1/public/${LOGIN}/tera_applications"
BENCHMARKS_REPO=${TERA_APPS_REPO}/lucene/benchmarks
COMPILE_OUT="${TERA_APPS_REPO}/lucene/compile.out"
