#!/usr/bin/env bash

# run_osb() {
#     local outfile="$1"
#     local params_file="$2"
#     local repeat_freq="$3"
#
#     print_status "Running OpenSearch Benchmark: bbox only" info
#
#     if [ "${DRY_RUN:-false}" == "true" ]; then
#         cat <<EOF_CMD
# opensearch-benchmark run \\
#   --pipeline=benchmark-only \\
#   --workload-path=${WORKLOAD_PATH} \\
#   --test-procedure=${TEST_PROCEDURE} \\
#   --include-tasks=${BENCHMARK_TASK} \\
#   --target-hosts=${TARGET_HOST} \\
#   --workload-params=${params_file} \\
#   --randomization-enabled \\
#   --randomization-repeat-frequency=${repeat_freq} \\
#   --randomization-n=${RANDOMIZATION_N} \\
#   --randomization-alpha=${RANDOMIZATION_ALPHA} \\
#   --on-error=abort \\
#   --kill-running-processes
# EOF_CMD
#         return 0
#     fi
#
#     echo
#     echo "=== OpenSearch Benchmark arguments ==="
#     echo "WORKLOAD_PATH=${WORKLOAD_PATH}"
#     echo "TEST_PROCEDURE=${TEST_PROCEDURE}"
#     echo "BENCHMARK_TASK=${BENCHMARK_TASK}"
#     echo "TARGET_HOST=${TARGET_HOST}"
#     echo "params_file=${params_file}"
#     echo "repeat_freq=${repeat_freq}"
#     echo "RANDOMIZATION_N=${RANDOMIZATION_N}"
#     echo "RANDOMIZATION_ALPHA=${RANDOMIZATION_ALPHA}"
#     echo "======================================"
#     echo
#
#     opensearch-benchmark run \
#         --pipeline=benchmark-only \
#         --workload-path="${WORKLOAD_PATH}" \
#         --test-procedure="${TEST_PROCEDURE}" \
#         --include-tasks="${BENCHMARK_TASK}" \
#         --target-hosts="${TARGET_HOST}" \
#         --workload-params="${params_file}" \
#         --randomization-enabled \
#         --randomization-repeat-frequency="${repeat_freq}" \
#         --randomization-n="${RANDOMIZATION_N}" \
#         --randomization-alpha="${RANDOMIZATION_ALPHA}" \
#         --on-error=abort \
#         --kill-running-processes \
#         > "${outfile}" 2>&1
# }

run_osb() {
    local outfile="$1"
    local params_file="$2"
    local repeat_freq="$3"

    print_status "Running OpenSearch Benchmark: bbox only" info

    if [ "${DRY_RUN:-false}" == "true" ]; then
        cat <<EOF_CMD
opensearch-benchmark run \\
  --pipeline=benchmark-only \\
  --workload-path=${WORKLOAD_PATH} \\
  --test-procedure=${TEST_PROCEDURE} \\
  --include-tasks=${BENCHMARK_TASK} \\
  --target-hosts=${TARGET_HOST} \\
  --workload-params=${params_file} \\
  --randomization-enabled \\
  --randomization-repeat-frequency=${repeat_freq} \\
  --randomization-n=${RANDOMIZATION_N} \\
  --randomization-alpha=${RANDOMIZATION_ALPHA} \\
  --on-error=abort \\
  --kill-running-processes
EOF_CMD
        return 0
    fi

    opensearch-benchmark run \
        --pipeline=benchmark-only \
        --workload-path="${WORKLOAD_PATH}" \
        --test-procedure="${TEST_PROCEDURE}" \
        --include-tasks="${BENCHMARK_TASK}" \
        --target-hosts="${TARGET_HOST}" \
        --workload-params="${params_file}" \
        --randomization-enabled \
        --randomization-repeat-frequency="${repeat_freq}" \
        --randomization-n="${RANDOMIZATION_N}" \
        --randomization-alpha="${RANDOMIZATION_ALPHA}" \
        --on-error=abort \
        --kill-running-processes \
        > "${outfile}" 2>&1
}

archive_osb_test_run() {
    local osb_log="$1"
    local run_dir="$2"

    local test_run_id
    local source_json
    local waited=0

    test_run_id=$(
        sed -n \
          's/.*\[Test Run ID\]:[[:space:]]*\([^[:space:]]*\).*/\1/p' \
          "${osb_log}" \
        | tail -1
    )

    if [ -z "${test_run_id}" ]; then
        echo "Could not find OSB Test Run ID in ${osb_log}" >&2
        return 1
    fi

    source_json="${BENCHMARK_HOME}/.osb/benchmarks/test-runs/${test_run_id}/test_run.json"

    while [ ! -f "${source_json}" ]; do
        sleep 1
        waited=$((waited + 1))

        if [ "${waited}" -ge 30 ]; then
            echo "OSB test_run.json not found: ${source_json}" >&2
            return 1
        fi
    done

    cp "${source_json}" "${run_dir}/test_run.json"
    printf '%s\n' "${test_run_id}" > "${run_dir}/test_run_id.txt"

    print_status "Archive OSB test_run.json (${test_run_id})" ok
}
