#!/usr/bin/env bash
###################################################
#
# file: run_cgexec.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Helper script executed inside the cgroup.
#         Sets up the environment and launches the
#         JVM with the provided options.
#
# Args:
#   $1  JAVA_HOME path
#   $2  TERAHEAP_REPO path
#   $3  java_opts string
#   $4  output directory
#   $5  benchmark size (large/vlarge)
#   $6  number of iterations
#   $7  benchmark name
###################################################

JAVA_HOME=$1
TERAHEAP_REPO=$2
JAVA_OPTS=$3
OUT_DIR=$4
BENCH_SIZE=$5
ITERATIONS=$6
BENCHMARK=$7

# Validate arguments
if [ -z "${JAVA_HOME}" ] || [ -z "${TERAHEAP_REPO}" ] || [ -z "${BENCHMARK}" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: $0 <java_home> <teraheap_repo> <java_opts> <out_dir> <size> <iterations> <benchmark>"
    exit 1
fi

# Environment setup
export JAVA_HOME="${JAVA_HOME}"
export PATH="${JAVA_HOME}/bin:${PATH}"

export LIBRARY_PATH="${TERAHEAP_REPO}/allocator/lib:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="${TERAHEAP_REPO}/allocator/lib:${LD_LIBRARY_PATH}"
export PATH="${TERAHEAP_REPO}/allocator/include:${PATH}"
export C_INCLUDE_PATH="${TERAHEAP_REPO}/allocator/include:${C_INCLUDE_PATH}"
export CPLUS_INCLUDE_PATH="${TERAHEAP_REPO}/allocator/include:${CPLUS_INCLUDE_PATH}"

# Run the benchmark
${JAVA_HOME}/bin/java ${JAVA_OPTS} \
-Djava.security.manager=allow \
-jar "${DACAPO_JAR}" \
-s "${BENCH_SIZE}" \
-t "${GC_THREADS}" \
-n "${ITERATIONS}" \
"${BENCHMARK}" \
--scratch-directory="${DACAPO_SCRATCH_DIR}" \
--no-validation \
> "${OUT_DIR}/out.txt" 2> "${OUT_DIR}/err.txt"
