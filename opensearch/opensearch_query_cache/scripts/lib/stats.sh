#!/usr/bin/env bash
MEM_MONITOR_PID=""
SYSTEM_STATS_STARTED=false

start_memory_monitor() {
    "${SCRIPT_DIR}/mem_usage.sh" "${RUN_DIR}/mem_usage.txt" "OpenSearch" &
    MEM_MONITOR_PID=$!
}

stop_memory_monitor() {
    if [ -n "${MEM_MONITOR_PID:-}" ]; then
        kill "${MEM_MONITOR_PID}" >/dev/null 2>&1 || true
        wait "${MEM_MONITOR_PID}" >/dev/null 2>&1 || true
        MEM_MONITOR_PID=""
    fi
}

start_system_stats() {
    "${SCRIPT_DIR}/system_util/start_statistics.sh" -d "${RUN_DIR}"
    SYSTEM_STATS_STARTED=true
}

stop_system_stats() {
    if [ "${SYSTEM_STATS_STARTED:-false}" == "true" ]; then
        "${SCRIPT_DIR}/system_util/stop_statistics.sh" -d "${RUN_DIR}" >/dev/null 2>&1 || true
        SYSTEM_STATS_STARTED=false
    fi
}

snapshot_cache() {
    local label="$1"

    # Primary cache under test: Lucene query cache.
    curl -sf "http://${TARGET_HOST}/_nodes/stats/indices/query_cache" \
        > "${RUN_DIR}/query-cache-${label}.json" 2>/dev/null || true

    # Sanity check only: request-cache traffic should stay at zero because
    # prepare_index() disables it for nyc_taxis.
    curl -sf "http://${TARGET_HOST}/_nodes/stats/indices/request_cache" \
        > "${RUN_DIR}/request-cache-${label}.json" 2>/dev/null || true
}

parse_cache_results() {
    python3 "${SCRIPT_DIR}/tools/parse_cache.py" "${RUN_DIR}" \
        | tee "${RUN_DIR}/cache_summary.txt"
}
