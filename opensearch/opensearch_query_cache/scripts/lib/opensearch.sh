#!/usr/bin/env bash
OS_START_TIMEOUT=${OS_START_TIMEOUT:-300}
OS_STOP_TIMEOUT=${OS_STOP_TIMEOUT:-120}

wait_for_opensearch() {
    local elapsed=0
    while ! curl -sf "http://${TARGET_HOST}/_cluster/health?wait_for_status=yellow&timeout=5s" >/dev/null 2>&1; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [ "${elapsed}" -ge "${OS_START_TIMEOUT}" ]; then
            echo "Timed out waiting for OpenSearch." >&2
            return 1
        fi
    done
}

start_opensearch() {
    local java_home
    if [ "${MODE}" == "teraheap" ]; then
        java_home="${MY_JAVA_HOME}"
    else
        java_home="${VANILLA_JAVA_HOME}"
    fi
    print_status "Starting OpenSearch (${MODE})" info
    run_step "Start OpenSearch" bash -c \
        "OPENSEARCH_JAVA_HOME=${java_home} \
         cgexec -g memory:memlim --sticky \
         '${SCRIPT_DIR}/run_cgexec.sh' \
         numactl --cpunodebind=0 --membind=0 \
         '${OPENSEARCH_DIR}/bin/opensearch' -d -p '${OPENSEARCH_DIR}/os.pid' \
         >> '${BENCH_LOG}' 2>&1"
    run_step "Wait for OpenSearch" wait_for_opensearch
}

stop_opensearch() {
    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Stop OpenSearch" skip
        return 0
    fi

    local pidfile="${OPENSEARCH_DIR}/os.pid"
    local pid=""
    if [ -f "${pidfile}" ]; then
        pid=$(cat "${pidfile}" 2>/dev/null || true)
    fi
    if [ -z "${pid}" ] || ! kill -0 "${pid}" 2>/dev/null; then
        pid=$(pgrep -f 'org\.opensearch\.bootstrap\.OpenSearch' | head -1 || true)
    fi
    if [ -z "${pid}" ]; then
        rm -f "${pidfile}"
        return 0
    fi
    print_status "Stopping OpenSearch PID ${pid}" info
    kill "${pid}" 2>/dev/null || true
    local waited=0
    while kill -0 "${pid}" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [ "${waited}" -ge "${OS_STOP_TIMEOUT}" ]; then
            print_status "Graceful shutdown timed out; sending SIGKILL" info
            kill -9 "${pid}" 2>/dev/null || true
            sleep 1
            break
        fi
    done
    rm -f "${pidfile}"
}

check_node_alive() {
    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Check OpenSearch survived" skip
        return 0
    fi

    if pgrep -f 'org\.opensearch\.bootstrap\.OpenSearch' >/dev/null; then
        return 0
    fi
    echo "OpenSearch died during the benchmark." >&2
    if [ -f /sys/fs/cgroup/memlim/memory.events ]; then
        cat /sys/fs/cgroup/memlim/memory.events >&2
    fi
    return 1
}

prepare_index() {
    # This workload is for the Lucene query cache. Disable the request cache so
    # size:0 bbox requests cannot be answered by the shard request cache before
    # Lucene executes the query.
    run_step "Configure nyc_taxis for query-cache experiment" curl -sf -X PUT \
        "http://${TARGET_HOST}/${INDEX}/_settings" \
        -H 'Content-Type: application/json' \
        -d '{
              "index.refresh_interval": "-1",
              "index.requests.cache.enable": false
            }'

    run_step "Clear query and request caches" curl -sf -X POST \
        "http://${TARGET_HOST}/${INDEX}/_cache/clear?query=true&request=true"

    run_step "Verify query-cache settings" bash -c \
        "settings=\$(curl -sf 'http://${TARGET_HOST}/${INDEX}/_settings?flat_settings=true&include_defaults=true') && \
         grep -q '\"index.requests.cache.enable\":\"false\"' <<< \"\${settings}\" && \
         grep -q '\"index.queries.cache.enabled\":\"true\"' <<< \"\${settings}\""
}
