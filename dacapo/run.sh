#!/usr/bin/env bash
###################################################
#
# file: run.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Run DaCapo benchmarks with TeraHeap or native G1
#
###################################################

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/conf.sh"

# Derived values
CARD_SIZE=$((8 * 1024))
STRIPE_SIZE=$(( REGION_SIZE / CARD_SIZE ))

# Colors
RED='\e[31;1m'
GREEN='\e[32;1m'
YELLOW='\e[33;1m'
CYAN='\e[36;1m'
BOLD='\e[1m'
RESET='\e[0m'

###################################################
# Usage
###################################################

usage() {
    echo -e "Usage: $0 [OPTIONS]"
    echo -e ""
    echo -e "Options:"
    echo -e "  -m, --mode <mode>             Run mode: 'teraheap' or 'native' (overrides conf.sh)"
    echo -e "  -r, --result-dir <dir>        Results directory (overrides conf.sh)"
    echo -e "  -b, --benchmark <name[,...]|all>"
    echo -e "                                Benchmark(s) to run: one name, a comma-separated"
    echo -e "                                list, or 'all' (overrides conf.sh BENCHMARKS)"
    echo -e "  -g, --gc-threads <n>          Number of GC/DaCapo threads (overrides conf.sh GC_THREADS)"
    echo -e "  -o, --dram-overhead <GB>      DRAM overhead above heap/H1 size, in GB (overrides conf.sh DRAM_OVERHEAD_GB)"
    echo -e "  -s, --size <size>             DaCapo input size: tiny/small/default/large/huge/gigantic/vlarge"
    echo -e "                                (overrides conf.sh BENCHMARK_SIZE for the selected benchmark(s))"
    echo -e "  -i, --iterations <n>          Number of DaCapo iterations (overrides conf.sh BENCHMARK_ITERATIONS"
    echo -e "                                for the selected benchmark(s))"
    echo -e "      --h1-size <v[,...]>       TeraHeap H1 size(s) (overrides conf.sh BENCHMARK_H1_SIZES for the"
    echo -e "                                selected benchmark(s)). Accepts MB (bare number or e.g. 2048m)"
    echo -e "                                or GB (e.g. 2g); comma-separate multiple values to sweep"
    echo -e "      --h2-file-size <v[,...]>  TeraHeap H2 file size(s) in GB (overrides conf.sh"
    echo -e "                                BENCHMARK_H2_FILE_SIZES for the selected benchmark(s));"
    echo -e "                                comma-separate multiple values to sweep"
    echo -e "  -l, --list-benchmarks        List configured benchmarks and exit"
    echo -e "  -d, --dry-run                 Dry run: print commands without executing"
    echo -e "  -h, --help                    Print this help message"
    echo -e ""
    echo -e "Examples:"
    echo -e "  $0 --mode native"
    echo -e "  $0 --mode teraheap --result-dir /tmp/results"
    echo -e "  $0 --mode native --benchmark h2"
    echo -e "  $0 --mode teraheap --benchmark h2,batik,fop --gc-threads 16 --dram-overhead 4"
    echo -e "  $0 --mode teraheap --benchmark h2 --h1-size 2g,4g,8g --h2-file-size 16,32"
    echo -e "  $0 --mode native --benchmark fop --size large --iterations 3"
    echo -e "  $0 --list-benchmarks"
    echo -e "  $0 --mode native --dry-run"
    echo -e "  $0 --mode teraheap --dry-run --result-dir /tmp/results"
    exit 0
}

###################################################
# Parse arguments
###################################################

DRY_RUN=false
BENCHMARK_ARG=""
DRAM_OVERHEAD_ARG=""
SIZE_ARG=""
ITERATIONS_ARG=""
H1_SIZE_ARG=""
H2_FILE_SIZE_ARG=""
LIST_BENCHMARKS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            RUN_MODE="$2"
            shift 2
            ;;
        -r|--result-dir)
            RESULT_DIR="$2"
            shift 2
            ;;
        -b|--benchmark)
            BENCHMARK_ARG="$2"
            shift 2
            ;;
        -g|--gc-threads)
            GC_THREADS="$2"
            shift 2
            ;;
        -o|--dram-overhead)
            DRAM_OVERHEAD_ARG="$2"
            shift 2
            ;;
        -s|--size)
            SIZE_ARG="$2"
            shift 2
            ;;
        -i|--iterations)
            ITERATIONS_ARG="$2"
            shift 2
            ;;
        --h1-size)
            H1_SIZE_ARG="$2"
            shift 2
            ;;
        --h2-file-size)
            H2_FILE_SIZE_ARG="$2"
            shift 2
            ;;
        -l|--list-benchmarks)
            LIST_BENCHMARKS=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unknown argument '$1'"
            usage
            ;;
    esac
done

if [ "${LIST_BENCHMARKS}" == "true" ]; then
    echo -e "${BOLD}${CYAN}Available benchmarks:${RESET}"
    printf "  %-12s %-10s %s\n" "NAME" "SIZE" "NATIVE_HEAP_MB"
    for b in $(printf '%s\n' "${!BENCHMARK_SIZE[@]}" | sort); do
        printf "  %-12s %-10s %s\n" "${b}" "${BENCHMARK_SIZE[$b]}" "${BENCHMARK_NATIVE_HEAP_MB[$b]}"
    done
    exit 0
fi

###################################################
# Validate
###################################################

if [ -z "${RESULT_DIR}" ]; then
    echo "ERROR: No result directory specified (use -r or set RESULT_DIR in conf.sh)"
    usage
fi

if [[ "${RUN_MODE}" != "teraheap" && "${RUN_MODE}" != "native" ]]; then
    echo "ERROR: RUN_MODE must be 'teraheap' or 'native' (got '${RUN_MODE}')"
    usage
fi

if [ -n "${BENCHMARK_ARG}" ] && [ "${BENCHMARK_ARG}" != "all" ]; then
    IFS=',' read -ra requested_benchmarks <<< "${BENCHMARK_ARG}"
    for b in "${requested_benchmarks[@]}"; do
        if [[ -z "${BENCHMARK_SIZE[$b]+x}" ]]; then
            echo "ERROR: Unknown benchmark '${b}'"
            echo "Available benchmarks: $(printf '%s\n' "${!BENCHMARK_SIZE[@]}" | sort | tr '\n' ' ')"
            exit 1
        fi
    done
    BENCHMARKS=("${requested_benchmarks[@]}")
fi

if ! [[ "${GC_THREADS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --gc-threads must be a positive integer (got '${GC_THREADS}')"
    exit 1
fi

if [ -n "${DRAM_OVERHEAD_ARG}" ]; then
    if ! [[ "${DRAM_OVERHEAD_ARG}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --dram-overhead must be a positive integer (got '${DRAM_OVERHEAD_ARG}')"
        exit 1
    fi
    for b in "${!BENCHMARK_DRAM_OVERHEAD[@]}"; do
        BENCHMARK_DRAM_OVERHEAD[$b]=${DRAM_OVERHEAD_ARG}
    done
fi

if [ -n "${SIZE_ARG}" ]; then
    ALLOWED_SIZES=(tiny small default large huge gigantic vlarge)
    size_valid=false
    for s in "${ALLOWED_SIZES[@]}"; do
        [[ "${SIZE_ARG}" == "${s}" ]] && size_valid=true && break
    done
    if ! ${size_valid}; then
        echo "ERROR: --size must be one of: ${ALLOWED_SIZES[*]} (got '${SIZE_ARG}')"
        exit 1
    fi
    for b in "${BENCHMARKS[@]}"; do
        BENCHMARK_SIZE[$b]="${SIZE_ARG}"
    done
fi

if [ -n "${ITERATIONS_ARG}" ]; then
    if ! [[ "${ITERATIONS_ARG}" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --iterations must be a positive integer (got '${ITERATIONS_ARG}')"
        exit 1
    fi
    for b in "${BENCHMARKS[@]}"; do
        BENCHMARK_ITERATIONS[$b]="${ITERATIONS_ARG}"
    done
fi

if [ -n "${H1_SIZE_ARG}" ]; then
    IFS=',' read -ra h1_tokens <<< "${H1_SIZE_ARG}"
    h1_mb_values=()
    for tok in "${h1_tokens[@]}"; do
        if [[ "${tok}" =~ ^([0-9]+)[gG][bB]?$ ]]; then
            h1_mb_values+=( $(( BASH_REMATCH[1] * 1024 )) )
        elif [[ "${tok}" =~ ^([0-9]+)[mM][bB]?$ ]]; then
            h1_mb_values+=( "${BASH_REMATCH[1]}" )
        elif [[ "${tok}" =~ ^[0-9]+$ ]]; then
            h1_mb_values+=( "${tok}" )
        else
            echo "ERROR: Invalid --h1-size value '${tok}' (expected MB, e.g. 2048 or 2048m, or GB, e.g. 2g)"
            exit 1
        fi
    done
    h1_sizes_str="${h1_mb_values[*]}"
    for b in "${BENCHMARKS[@]}"; do
        BENCHMARK_H1_SIZES[$b]="${h1_sizes_str}"
    done
fi

if [ -n "${H2_FILE_SIZE_ARG}" ]; then
    IFS=',' read -ra h2_tokens <<< "${H2_FILE_SIZE_ARG}"
    for tok in "${h2_tokens[@]}"; do
        if ! [[ "${tok}" =~ ^[0-9]+$ ]]; then
            echo "ERROR: Invalid --h2-file-size value '${tok}' (expected GB integer, e.g. 4)"
            exit 1
        fi
    done
    h2_sizes_str="${h2_tokens[*]}"
    for b in "${BENCHMARKS[@]}"; do
        BENCHMARK_H2_FILE_SIZES[$b]="${h2_sizes_str}"
    done
fi

# Environment setup
export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include:$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include:$CPLUS_INCLUDE_PATH
export GC_THREADS
export DACAPO_JAR
export DACAPO_SCRATCH_DIR

###################################################
# Progress tracking
###################################################

TOTAL_RUNS=0
CURRENT_RUN=0
PROGRESS_START_TIME=0

compute_total_runs() {
    local total=0
    for benchmark in "${BENCHMARKS[@]}"; do
        if [[ "${RUN_MODE}" == "native" ]]; then
            total=$(( total + 1 ))
        else
            read -ra h1_sizes      <<< "${BENCHMARK_H1_SIZES[$benchmark]}"
            read -ra h2_file_sizes <<< "${BENCHMARK_H2_FILE_SIZES[$benchmark]}"
            total=$(( total + ${#h1_sizes[@]} * ${#h2_file_sizes[@]} ))
        fi
    done
    TOTAL_RUNS=${total}
}

format_time() {
    local secs=$1
    printf "%02d:%02d:%02d" $(( secs/3600 )) $(( (secs%3600)/60 )) $(( secs%60 ))
}

print_progress() {
    local benchmark=$1
    local config=$2

    local now
    now=$(date +%s)
    local elapsed=$(( now - PROGRESS_START_TIME ))
    local elapsed_str
    elapsed_str=$(format_time "${elapsed}")

    local eta_str="--:--:--"
    if [ "${CURRENT_RUN}" -gt 0 ]; then
        local avg_time=$(( elapsed / CURRENT_RUN ))
        local remaining=$(( (TOTAL_RUNS - CURRENT_RUN) * avg_time ))
        eta_str=$(format_time "${remaining}")
    fi

    local bar_width=30
    local filled=$(( bar_width * CURRENT_RUN / TOTAL_RUNS ))
    local empty=$(( bar_width - filled ))
    local bar=""
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty;  i++ )); do bar+="░"; done

    echo -e "\n${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET} Progress  [${GREEN}${bar}${RESET}] ${BOLD}${CURRENT_RUN}/${TOTAL_RUNS}${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET} Mode      ${BOLD}${RUN_MODE}${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET} Benchmark ${BOLD}${benchmark}${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET} Config    ${BOLD}${config}${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET} Elapsed   ${elapsed_str}    ETA  ${eta_str}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────┘${RESET}"
}

print_summary() {
    local now
    now=$(date +%s)
    local elapsed=$(( now - PROGRESS_START_TIME ))
    local elapsed_str
    elapsed_str=$(format_time "${elapsed}")

    echo -e "\n${BOLD}${GREEN}┌─────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${GREEN}│${RESET}  ${GREEN}All runs completed${RESET}"
    echo -e "${BOLD}${GREEN}│${RESET}  Mode:        ${BOLD}${RUN_MODE}${RESET}"
    echo -e "${BOLD}${GREEN}│${RESET}  Total runs:  ${BOLD}${TOTAL_RUNS}${RESET}"
    echo -e "${BOLD}${GREEN}│${RESET}  Total time:  ${BOLD}${elapsed_str}${RESET}"
    echo -e "${BOLD}${GREEN}│${RESET}  Results:     ${BOLD}${RESULT_DIR}${RESET}"
    echo -e "${BOLD}${GREEN}└─────────────────────────────────────────────────────────────┘${RESET}"
}

###################################################
# Helpers
###################################################

check() {
    if [ "$1" -ne 0 ]; then
        echo -e "  $2 \e[40G [${RED}FAIL${RESET}]"
        exit 1
    else
        echo -e "  $2 \e[40G [${GREEN}SUCCEED${RESET}]"
    fi
}

run_cmd() {
    local desc=$1
    shift
    if [ "${DRY_RUN}" == "true" ]; then
        echo -e "  ${YELLOW}▷ ${desc}${RESET}"
        echo -e "      ${BOLD}cmd:${RESET} $*"
        echo -e "      └─ [dry]"
    else
        "$@"
    fi
}

###################################################
# Cgroup management
###################################################

setup_cgroup() {
    local dram_budget_gb=$1
    local mem_budget_bytes
    mem_budget_bytes=$(echo "${dram_budget_gb} * 1024 * 1024 * 1024" | bc | awk '{printf "%d\n", $1}')

    run_cmd "Create cgroup" \
        sudo cgcreate -a "$(whoami):sudo" -t "$(whoami):sudo" -g memory:${CGROUP_NAME}
    [ "${DRY_RUN}" != "true" ] && check $? "Create cgroup '${CGROUP_NAME}'" || true

    run_cmd "Set cgroup memory limit" \
        cgset -r memory.max="${mem_budget_bytes}" ${CGROUP_NAME}
    [ "${DRY_RUN}" != "true" ] && check $? "Set cgroup memory limit to ${dram_budget_gb}GB" || true

    run_cmd "Set cgroup permissions" \
        sudo chmod o+w /sys/fs/cgroup/cgroup.procs
    [ "${DRY_RUN}" != "true" ] && check $? "Set cgroup permissions" || true
}

delete_cgroup() {
    run_cmd "Delete cgroup" \
        sudo cgdelete memory:${CGROUP_NAME}
    [ "${DRY_RUN}" != "true" ] && check $? "Delete cgroup '${CGROUP_NAME}'" || true
}

run_cgexec() {
    if [ "${DRY_RUN}" == "true" ]; then
        echo -e "  ${YELLOW}▷ run_cgexec${RESET}"
        echo -e "      ${BOLD}cmd:${RESET} cgexec -g memory:${CGROUP_NAME} --sticky ${SCRIPT_DIR}/run_cgexec.sh $*"
        echo -e "      └─ [dry]"
    else
        cgexec -g memory:${CGROUP_NAME} --sticky \
            "${SCRIPT_DIR}/run_cgexec.sh" "$@" >> "${BENCH_LOG}" 2>&1
    fi
}

###################################################
# CPU mode management
###################################################

set_cpu_perf_mode() {
    run_cmd "Set CPU performance mode" \
        sudo "${SCRIPT_DIR}/cpu_perf.sh" -p
    [ "${DRY_RUN}" != "true" ] && check $? "Set CPU performance mode" || true
}

set_cpu_sched_mode() {
    run_cmd "Set CPU schedule mode" \
        sudo "${SCRIPT_DIR}/cpu_perf.sh" -s
    [ "${DRY_RUN}" != "true" ] && check $? "Set CPU schedule mode" || true
}

###################################################
# Save run configuration
###################################################

save_config() {
    local out_dir=$1
    local benchmark=$2
    local java_opts=$3
    local size=$4
    local iterations=$5
    local mode=$6
    local config_file="${out_dir}/run_config.txt"

    cat > "${config_file}" << EOF
###################################################
# Run Configuration
# Generated: $(date)
###################################################

# General
MODE:           ${mode}
BENCHMARK:      ${benchmark}
SIZE:           ${size}
ITERATIONS:     ${iterations}
DRY_RUN:        ${DRY_RUN}

# JVM
JAVA_HOME:      ${JAVA_HOME}
JAVA_OPTS:      ${java_opts}

# DaCapo command
CMD:            ${JAVA_HOME}/bin/java ${java_opts} \\
                    -jar dacapo-23.11-chopin.jar \\
                    -s ${size} \\
                    -t ${GC_THREADS} \\
                    -n ${iterations} \\
                    ${benchmark}

# Environment
TERAHEAP_REPO:          ${TERAHEAP_REPO}
LIBRARY_PATH:           ${TERAHEAP_REPO}/allocator/lib
LD_LIBRARY_PATH:        ${TERAHEAP_REPO}/allocator/lib
C_INCLUDE_PATH:         ${TERAHEAP_REPO}/allocator/include
CPLUS_INCLUDE_PATH:     ${TERAHEAP_REPO}/allocator/include

# Cgroup
CGROUP_NAME:    ${CGROUP_NAME}
EOF

    # Append mode-specific config
    if [[ "${mode}" == "native" ]]; then
        cat >> "${config_file}" << EOF

# Native G1 specific
HEAP_MB:        ${BENCHMARK_NATIVE_HEAP_MB[$benchmark]}
DRAM_BUDGET_GB: $(( $(echo "scale=0; (${BENCHMARK_NATIVE_HEAP_MB[$benchmark]} + 1023) / 1024" | bc) + ${BENCHMARK_DRAM_OVERHEAD[$benchmark]} ))
GC_THREADS:     ${GC_THREADS}
G1_REGION_SIZE: ${G1_HEAP_REGION_SZ}
EOF
    else
        cat >> "${config_file}" << EOF

# TeraHeap specific
H1_SIZE_GB:     $7
H2_FILE_SZ_GB:  $8
H1_H2_SIZE_GB:  ${H1_H2_SIZE}
DRAM_BUDGET_GB: $9
TH_BYTES:       ${10}
H2_FILE_BYTES:  ${11}
GC_THREADS:     ${GC_THREADS}
G1_REGION_SIZE: ${G1_HEAP_REGION_SZ}
STRIPE_SIZE:    ${STRIPE_SIZE}
ENABLE_STATS:   ${ENABLE_STATS}
MNT_H2:         ${MNT_H2}
EOF
    fi

    echo -e "  ${BOLD}Config saved:${RESET} ${config_file}"
}

###################################################
# Benchmark runners
###################################################

run_native() {
    local benchmark=$1
    local iterations=${BENCHMARK_ITERATIONS[$benchmark]}
    local size=${BENCHMARK_SIZE[$benchmark]}
    local heap_mb=${BENCHMARK_NATIVE_HEAP_MB[$benchmark]}
    local dram_overhead=${BENCHMARK_DRAM_OVERHEAD[$benchmark]}

    # Ceiling divide MB to GB for cgroup budget
    local heap_gb_ceil
    heap_gb_ceil=$(echo "scale=0; (${heap_mb} + 1023) / 1024" | bc)
    local dram_budget=$(( heap_gb_ceil + dram_overhead ))

    local out_dir="${RESULT_DIR}/native/${benchmark}/heap_${heap_mb}mb_dram_${dram_budget}g_region_${G1_HEAP_REGION_SZ}"

    CURRENT_RUN=$(( CURRENT_RUN + 1 ))
    print_progress "${benchmark}" "heap=${heap_mb}mb | dram=${dram_budget}g | size=${size} | iters=${iterations}"

    mkdir -p "${out_dir}"
    BENCH_LOG="${out_dir}/bench.log"

    local java_opts
    java_opts="-XX:-ClassUnloading -XX:+UseG1GC -XX:ParallelGCThreads=${GC_THREADS} "
    java_opts+="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers "
    java_opts+="-Xmx${heap_mb}m "
    java_opts+="-XX:G1HeapRegionSize=${G1_HEAP_REGION_SZ} "
    java_opts+="-XX:+ShowMessageBoxOnError "
    java_opts+="-Xlog:gc*:file=${out_dir}/gc.log::filecount=1,filesize=500M "
    java_opts+="-XX:ErrorFile=${out_dir}/hs_err.log"

    save_config \
        "${out_dir}" \
        "${benchmark}" \
        "${java_opts}" \
        "${size}" \
        "${iterations}" \
        "native"

    setup_cgroup "${dram_budget}"
    run_cgexec \
        "${JAVA_HOME}" \
        "${TERAHEAP_REPO}" \
        "${java_opts}" \
        "${out_dir}" \
        "${size}" \
        "${iterations}" \
        "${benchmark}"
    [ "${DRY_RUN}" != "true" ] && check $? "Run benchmark ${benchmark}" || true
    delete_cgroup
}

run_teraheap() {
    local benchmark=$1
    local h1_size_mb=$2
    local h2_file_sz=$3
    local iterations=${BENCHMARK_ITERATIONS[$benchmark]}
    local size=${BENCHMARK_SIZE[$benchmark]}
    local dram_overhead=${BENCHMARK_DRAM_OVERHEAD[$benchmark]}

    # Convert H1 MB to GB ceiling for cgroup and TH_BYTES calculation
    local h1_size_gb_ceil
    h1_size_gb_ceil=$(echo "scale=0; (${h1_size_mb} + 1023) / 1024" | bc)
    local dram_budget=$(( h1_size_gb_ceil + dram_overhead ))

    local out_dir="${RESULT_DIR}/teraheap/${benchmark}/heap_${h1_size_mb}mb_h2_${h2_file_sz}g_dram_${dram_budget}g_region_${G1_HEAP_REGION_SZ}"

    CURRENT_RUN=$(( CURRENT_RUN + 1 ))
    print_progress "${benchmark}" "h1=${h1_size_mb}mb | h2_file=${h2_file_sz}g | dram=${dram_budget}g | size=${size} | iters=${iterations}"

    mkdir -p "${out_dir}"
    BENCH_LOG="${out_dir}/bench.log"

    local th_bytes
    th_bytes=$(echo "(${H1_H2_SIZE} * 1024 - ${h1_size_mb}) * 1024 * 1024" | bc | awk '{printf "%d\n", $1}')

    local h2_file_sz_bytes
    h2_file_sz_bytes=$(echo "${h2_file_sz} * 1024 * 1024 * 1024" | bc | awk '{printf "%d\n", $1}')

    local java_opts
    java_opts="-XX:-ClassUnloading -XX:+UseG1GC -XX:ParallelGCThreads=${GC_THREADS} "
    java_opts+="-XX:+EnableTeraHeap -XX:TeraHeapSize=${th_bytes} "
    java_opts+="-Xmx${H1_H2_SIZE}g -Xms${h1_size_mb}m "
    java_opts+="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers "
    java_opts+="-XX:G1HeapRegionSize=${G1_HEAP_REGION_SZ} "
    java_opts+="-XX:TeraStripeSize=${STRIPE_SIZE} "
    java_opts+="-XX:+ShowMessageBoxOnError "

    if ${ENABLE_STATS}; then
        java_opts+="-XX:+TeraHeapStatistics -Xlogth:${out_dir}/teraHeap.txt "
    fi

    java_opts+="-XX:AllocateH2At=${MNT_H2}/ -XX:H2FileSize=${h2_file_sz_bytes} "
    java_opts+="-Xlog:gc*:file=${out_dir}/gc.log::filecount=1,filesize=500M "
    java_opts+="-XX:ErrorFile=${out_dir}/hs_err.log"

    save_config \
        "${out_dir}" \
        "${benchmark}" \
        "${java_opts}" \
        "${size}" \
        "${iterations}" \
        "teraheap" \
        "${h1_size_mb}" \
        "${h2_file_sz}" \
        "${dram_budget}" \
        "${th_bytes}" \
        "${h2_file_sz_bytes}"

    setup_cgroup "${dram_budget}"
    run_cgexec \
        "${JAVA_HOME}" \
        "${TERAHEAP_REPO}" \
        "${java_opts}" \
        "${out_dir}" \
        "${size}" \
        "${iterations}" \
        "${benchmark}"
    [ "${DRY_RUN}" != "true" ] && check $? "Run benchmark ${benchmark}" || true
    delete_cgroup
}

###################################################
# Main
###################################################

compute_total_runs
PROGRESS_START_TIME=$(date +%s)

echo -e "${BOLD}${CYAN}===== Run Configuration =====${RESET}"
echo -e "  Mode:       ${RUN_MODE}"
echo -e "  Result dir: ${RESULT_DIR}"
echo -e "  Dry run:    ${DRY_RUN}"
echo -e "  Benchmarks: ${BENCHMARKS[*]}"
echo -e "  Total runs: ${TOTAL_RUNS}"
echo -e "${BOLD}${CYAN}=============================${RESET}"
echo ""

# Set CPU to performance mode before starting
set_cpu_perf_mode

for benchmark in "${BENCHMARKS[@]}"; do
    if [[ "${RUN_MODE}" == "native" ]]; then
        run_native "${benchmark}"

    elif [[ "${RUN_MODE}" == "teraheap" ]]; then
        read -ra h1_sizes      <<< "${BENCHMARK_H1_SIZES[$benchmark]}"
        read -ra h2_file_sizes <<< "${BENCHMARK_H2_FILE_SIZES[$benchmark]}"
        for h1 in "${h1_sizes[@]}"; do
            for h2f in "${h2_file_sizes[@]}"; do
                run_teraheap "${benchmark}" "${h1}" "${h2f}"
            done
        done
    fi
done

# Restore CPU to schedutil mode after all benchmarks finish
set_cpu_sched_mode

print_summary
