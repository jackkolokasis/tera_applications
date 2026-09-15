#!/usr/bin/env bash

write_workload_params() {
    local load="$1"
    local rf="$2"
    local run_dir="$3"
    local params_file="${run_dir}/params.json"

    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "bbox workload parameters for load${load}" info
        echo "      target_throughput=${TP_BBOX[$load]}"
        echo "      search_clients=${BBOX_SEARCH_CLIENTS}"
        echo "      warmup_iterations=${BBOX_WARMUP_ITERATIONS}"
        echo "      iterations=${BBOX_ITERATIONS}"
        echo "      repeat_freq=${rf}"
        echo "      randomization_n=${RANDOMIZATION_N}"
        echo "      randomization_alpha=${RANDOMIZATION_ALPHA}"
        return 0
    fi

    python3 "${SCRIPT_DIR}/tools/update_params.py" \
        --snapshot "${params_file}" \
        --target-throughput "${TP_BBOX[$load]}" \
        --target-update-throughput "${TP_UPDATE[$load]}" \
        --search-clients "${BBOX_SEARCH_CLIENTS}" \
        --warmup-iterations "${BBOX_WARMUP_ITERATIONS}" \
        --iterations "${BBOX_ITERATIONS}" \
        --repeat-freq "${rf}" \
        --randomization-n "${RANDOMIZATION_N}" \
        --randomization-alpha "${RANDOMIZATION_ALPHA}"
}
