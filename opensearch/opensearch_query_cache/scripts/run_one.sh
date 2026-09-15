#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/conf.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/cgroup.sh"
source "${SCRIPT_DIR}/lib/opensearch.sh"
source "${SCRIPT_DIR}/lib/benchmark.sh"
source "${SCRIPT_DIR}/lib/stats.sh"
source "${SCRIPT_DIR}/lib/artifacts.sh"

: "${RUN_DIR:?RUN_DIR is required}"
: "${MODE:?MODE is required}"
: "${CONF_INDEX:?CONF_INDEX is required}"
: "${REPEAT_FREQ:?REPEAT_FREQ is required}"

DRY_RUN="${DRY_RUN:-false}"
BENCH_LOG="${RUN_DIR}/bench.log"
PARAMS_FILE="${RUN_DIR}/params.json"

cleanup() {
    set +e

    if [ "${DRY_RUN}" != "true" ]; then
        stop_system_stats
        stop_memory_monitor
    fi

    stop_opensearch
    delete_cgroup
}

delete_and_update_index() {
    rm -rf ${MNT_DATA}/opensearch-data
    cp -a ${MNT_DATA}/backup/opensearch-data ${MNT_DATA}/
    rm -rf ${MNT_DATA}/opensearch-logs
    mkdir -p ${MNT_DATA}/opensearch-logs
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

###################################################
# Fresh JVM boundary for each load point.
###################################################

stop_opensearch
delete_cgroup

###################################################
# Configuration and fresh environment.
###################################################

run_step \
    "Update OpenSearch configuration" \
    "${SCRIPT_DIR}/update_conf.sh" \
        "${CONF_INDEX}" \
        "${MODE}"

setup_cgroup
drop_page_cache
delete_and_update_index

###################################################
# Start a NEW OpenSearch JVM for this point.
###################################################

start_opensearch
prepare_index

###################################################
# Real-only monitoring.
###################################################

if [ "${DRY_RUN}" != "true" ]; then
    start_memory_monitor

    run_step \
        "Start system statistics" \
        start_system_stats

    snapshot_cache before
else
    print_status "Start memory monitor" skip
    print_status "Start system statistics" skip
    print_status "Snapshot query-cache stats (before)" skip
fi

###################################################
# Exactly one benchmark/load point: bbox only.
###################################################

run_step \
    "OpenSearch Benchmark: bbox" \
    run_osb \
        "${RUN_DIR}/osb_run.txt" \
        "${PARAMS_FILE}" \
        "${REPEAT_FREQ}"

if [ "${DRY_RUN}" != "true" ]; then
    run_step \
        "Archive OSB test run" \
        archive_osb_test_run \
            "${RUN_DIR}/osb_run.txt" \
            "${RUN_DIR}"

    run_step \
        "Check OpenSearch survived" \
        check_node_alive

    snapshot_cache after

    stop_system_stats
    stop_memory_monitor

    parse_cache_results
else
    print_status "Check OpenSearch survived" skip
    print_status "Snapshot query-cache stats (after)" skip
    print_status "Parse query-cache statistics" skip
fi

###################################################
# Explicit shutdown BEFORE returning to run.sh.
###################################################

stop_opensearch
delete_cgroup

###################################################
# Real-only result extraction.
###################################################

if [ "${DRY_RUN}" != "true" ]; then
    extract_statistics
    save_artifacts
else
    print_status "Extract system statistics" skip
    print_status "Save run artifacts" skip
fi

trap - EXIT INT TERM

print_status "bbox throughput run completed" ok

exit 0
