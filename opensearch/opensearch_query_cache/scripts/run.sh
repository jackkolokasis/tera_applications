#!/usr/bin/env bash
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/conf.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/params.sh"

ITER=""
OUTPUT_PATH=""
MODE="onheap"
DRY_RUN=false
REPEAT_FREQ_ARG=""
H1_ARG=""
CACHE_ARG=""
MEM_BUDGET_ARG=""
TP_BBOX_ARG=""
TP_UPDATE_ARG=""
SEARCH_CLIENTS_ARG=""
WARMUP_ITERATIONS_ARG=""
ITERATIONS_ARG=""
RANDOMIZATION_N_ARG=""
RANDOMIZATION_ALPHA_ARG=""

usage() {
    cat <<EOF_USAGE
Usage:
  $0 -n <runs> -o <output> [options]

General options:
  -n  Number of repetitions
  -o  Output path
  -m  Mode: onheap | teraheap
  -H  Heap sizes in GB, comma separated
  -c  Lucene query-cache sizes, comma separated (e.g. 512mb,1g or 10%)
  -M  cgroup memory budget, e.g. 16G
  -f  randomization repeat-frequency values, comma separated (0.0..1.0)
  -r  Dry run
  -h  Show help

bbox options:
  --tp-bbox=               Target throughput values, comma separated
  --search-clients=        Search clients for bbox
  --warmup-iterations=     bbox warmup iterations
  --iterations=            bbox measured iterations
  --randomization-n=       Number of saved randomized bbox values
  --randomization-alpha=   Zipf alpha for repeated bbox values

The OpenSearch Benchmark invocation always uses:
  --test-procedure=${TEST_PROCEDURE}
  --include-tasks=${BENCHMARK_TASK}
  --randomization-enabled

Therefore only the bbox task executes; delete/create/index/merge tasks from the
full test procedure are skipped. The nyc_taxis index must already exist.
EOF_USAGE
    exit 1
}

set_array_from_csv() {
    local name="$1"
    local value="$2"
    [ -z "${value}" ] && return
    local -n array="${name}"
    IFS=',' read -r -a array <<< "${value}"
}

validate_tp_array() {
    TOTAL_LOAD_POINTS=${#TP_BBOX[@]}
    [ "${TOTAL_LOAD_POINTS}" -gt 0 ] || {
        echo "Error: TP_BBOX is empty." >&2
        exit 1
    }
}

LONG_OPTS="tp-bbox:,search-clients:,warmup-iterations:,iterations:,randomization-n:,randomization-alpha:,tp-update:"
PARSED=$(getopt -o n:o:m:H:c:M:f:rh --long "${LONG_OPTS}" -- "$@") || usage
eval set -- "${PARSED}"

while true; do
    case "$1" in
        -n) ITER="$2"; shift 2 ;;
        -o) OUTPUT_PATH="$2"; shift 2 ;;
        -m) MODE="$2"; shift 2 ;;
        -H) H1_ARG="$2"; shift 2 ;;
        -c) CACHE_ARG="$2"; shift 2 ;;
        -M) MEM_BUDGET_ARG="$2"; shift 2 ;;
        -f) REPEAT_FREQ_ARG="$2"; shift 2 ;;
        -r) DRY_RUN=true; shift ;;
        -h) usage ;;
        --tp-bbox) TP_BBOX_ARG="$2"; shift 2 ;;
        --tp-update) TP_UPDATE_ARG="$2"; shift 2 ;;
        --search-clients) SEARCH_CLIENTS_ARG="$2"; shift 2 ;;
        --warmup-iterations) WARMUP_ITERATIONS_ARG="$2"; shift 2 ;;
        --iterations) ITERATIONS_ARG="$2"; shift 2 ;;
        --randomization-n) RANDOMIZATION_N_ARG="$2"; shift 2 ;;
        --randomization-alpha) RANDOMIZATION_ALPHA_ARG="$2"; shift 2 ;;
        --) shift; break ;;
        *) usage ;;
    esac
done

[ -n "${ITER}" ] && [ -n "${OUTPUT_PATH}" ] || usage
case "${MODE}" in
    onheap|teraheap) ;;
    offheap)
        echo "Error: offheap mode in the old harness configures the pluggable REQUEST cache." >&2
        echo "This bbox harness targets the Lucene QUERY cache, so offheap is intentionally disabled." >&2
        exit 1
        ;;
    *)
        echo "Error: invalid mode ${MODE} (expected onheap or teraheap)" >&2
        exit 1
        ;;
esac

if [ -n "${H1_ARG}" ]; then
    H1_SIZE_CSV="${H1_ARG}"
    IFS=',' read -r -a H1_SIZE <<< "${H1_ARG}"
fi
if [ -n "${CACHE_ARG}" ]; then
    QUERY_CACHE_SIZE_CSV="${CACHE_ARG}"
    IFS=',' read -r -a QUERY_CACHE_SIZE <<< "${CACHE_ARG}"
fi
if [ -n "${MEM_BUDGET_ARG}" ]; then MEM_BUDGET="${MEM_BUDGET_ARG}"; fi
export H1_SIZE_CSV QUERY_CACHE_SIZE_CSV MEM_BUDGET

if [ "${#H1_SIZE[@]}" -ne "${#QUERY_CACHE_SIZE[@]}" ]; then
    echo "Error: heap and query-cache configuration counts differ." >&2
    exit 1
fi
TOTAL_CONFS=${#H1_SIZE[@]}

set_array_from_csv TP_BBOX "${TP_BBOX_ARG}"
set_array_from_csv TP_UPDATE "${TP_UPDATE_ARG}"
validate_tp_array

if [ -n "${REPEAT_FREQ_ARG}" ]; then
    IFS=',' read -r -a REPEAT_FREQUENCIES <<< "${REPEAT_FREQ_ARG}"
fi
if [ -n "${SEARCH_CLIENTS_ARG}" ]; then BBOX_SEARCH_CLIENTS="${SEARCH_CLIENTS_ARG}"; fi
if [ -n "${WARMUP_ITERATIONS_ARG}" ]; then BBOX_WARMUP_ITERATIONS="${WARMUP_ITERATIONS_ARG}"; fi
if [ -n "${ITERATIONS_ARG}" ]; then BBOX_ITERATIONS="${ITERATIONS_ARG}"; fi
if [ -n "${RANDOMIZATION_N_ARG}" ]; then RANDOMIZATION_N="${RANDOMIZATION_N_ARG}"; fi
if [ -n "${RANDOMIZATION_ALPHA_ARG}" ]; then RANDOMIZATION_ALPHA="${RANDOMIZATION_ALPHA_ARG}"; fi
export BBOX_SEARCH_CLIENTS BBOX_WARMUP_ITERATIONS BBOX_ITERATIONS RANDOMIZATION_N RANDOMIZATION_ALPHA

# Validate randomization repeat frequencies before changing the machine state.
for rf in "${REPEAT_FREQUENCIES[@]}"; do
    python3 - "${rf}" <<'PY'
import sys
v = float(sys.argv[1])
if not 0.0 <= v <= 1.0:
    raise SystemExit(f"repeat frequency must be in [0,1], got {v}")
PY
done

if [ "${DRY_RUN}" != "true" ]; then
    command -v opensearch-benchmark >/dev/null || {
        echo "opensearch-benchmark not found." >&2
        exit 1
    }
fi

# Make failures caused by a wrong checkout obvious before starting experiments.
if [ "${DRY_RUN}" != "true" ]; then
    [ -d "${WORKLOAD_PATH}" ] || {
        echo "Workload path does not exist: ${WORKLOAD_PATH}" >&2
        exit 1
    }
    [ -f "${WORKLOAD_PATH}/test_procedures/default.json" ] || {
        echo "Missing ${WORKLOAD_PATH}/test_procedures/default.json" >&2
        exit 1
    }
    [ -f "${WORKLOAD_PATH}/operations/default.json" ] || {
        echo "Missing ${WORKLOAD_PATH}/operations/default.json" >&2
        exit 1
    }
    [ -f "${WORKLOAD_PATH}/workload.py" ] || {
        echo "Missing ${WORKLOAD_PATH}/workload.py; bbox randomization requires it." >&2
        exit 1
    }
fi

download_system_util
create_run_cgexec
set_cpu_perf_mode

cleanup_driver() {
    if [ "${DRY_RUN}" != "true" ]; then
        set_cpu_sched_mode >/dev/null 2>&1 || true
    fi
}
trap cleanup_driver EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

TIME=$(date +"%H-%M-%S-%d-%m-%Y")
OUT="${OUTPUT_PATH}_${MODE}_${TIME}"

if [ "${DRY_RUN}" == "true" ]; then
    print_status "Create output directory ${OUT}" skip
else
    mkdir -p "${OUT}"
fi

for ((run=0; run<ITER; run++)); do
    for ((conf=0; conf<TOTAL_CONFS; conf++)); do
        for ((load=0; load<TOTAL_LOAD_POINTS; load++)); do
            for rf in "${REPEAT_FREQUENCIES[@]}"; do
                RUN_DIR="${OUT}/run${run}/conf${conf}/load${load}/rf${rf}"

                if [ "${DRY_RUN}" != "true" ]; then
                    mkdir -p "${RUN_DIR}"
                fi
                echo
                echo "============================================================"
                echo "run=${run} conf=${conf} load=${load} bbox_tp=${TP_BBOX[$load]} repeat_freq=${rf}"
                echo "============================================================"
                echo

                write_workload_params "${load}" "${rf}" "${RUN_DIR}"

                # One invocation = one fresh OpenSearch process.
                RUN_DIR="${RUN_DIR}" \
                MODE="${MODE}" \
                CONF_INDEX="${conf}" \
                REPEAT_FREQ="${rf}" \
                DRY_RUN="${DRY_RUN}" \
                    "${SCRIPT_DIR}/run_one.sh"
                rc=$?
                if [ "${rc}" -ne 0 ]; then
                    echo "Run failed: run=${run} conf=${conf} load=${load} rf=${rf}" >&2
                    exit "${rc}"
                fi
            done
        done
    done
done

if [ "${DRY_RUN}" != "true" ]; then
    set_cpu_sched_mode
fi

trap - EXIT INT TERM

echo
echo "All bbox experiments completed."
