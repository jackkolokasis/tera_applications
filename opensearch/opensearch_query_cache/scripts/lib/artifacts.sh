#!/usr/bin/env bash
extract_statistics() {
    if [ "${MODE}" == "teraheap" ]; then
        "${SCRIPT_DIR}/system_util/extract-data.sh" -r "${RUN_DIR}" \
            -d "${DEV_DATA}" -d "${DEV_H2}"
    else
        "${SCRIPT_DIR}/system_util/extract-data.sh" -r "${RUN_DIR}" \
            -d "${DEV_DATA}"
    fi
}

save_artifacts() {
    cp "${SCRIPT_DIR}/conf.sh" "${RUN_DIR}/"
    cp "${OPENSEARCH_DIR}/config/opensearch.yml" "${RUN_DIR}/" 2>/dev/null || true
    cp "${OPENSEARCH_DIR}/config/jvm.options.d/experiment.options" "${RUN_DIR}/" 2>/dev/null || true
    cp "${WORKLOAD_PATH}/test_procedures/default.json" "${RUN_DIR}/test_procedure.json" 2>/dev/null || true
    cp "${WORKLOAD_PATH}/operations/default.json" "${RUN_DIR}/operations.json" 2>/dev/null || true
    cp "${WORKLOAD_PATH}/workload.py" "${RUN_DIR}/workload.py" 2>/dev/null || true
    mv ${MNT_DATA}/opensearch-logs/gc-*.log "${RUN_DIR}/" 2>/dev/null || true
    mv ${MNT_DATA}/opensearch-logs/teraheap-eval*.log "${RUN_DIR}/" 2>/dev/null || true
    if [ "${MODE}" == "teraheap" ]; then
        mv "${MNT_H2}/teraheap.txt" "${RUN_DIR}/" 2>/dev/null || true
    fi
}
