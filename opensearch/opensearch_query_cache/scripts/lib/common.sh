#!/usr/bin/env bash

RED='\e[31;1m'
GREEN='\e[32;1m'
YELLOW='\e[33;1m'
CYAN='\e[36;1m'
BOLD='\e[1m'
RESET='\e[0m'

print_status() {
    local msg="$1"
    local status="$2"

    case "${status}" in
        info) echo -e "  ${CYAN}▶ ${msg}${RESET}" ;;
        ok)   echo -e "  ${msg} ... [ ${GREEN}OK${RESET} ]" ;;
        fail) echo -e "  ${msg} ... [ ${RED}FAIL${RESET} ]" ;;
        skip) echo -e "  ${msg} ... [ ${YELLOW}SKIP${RESET} ]" ;;
    esac
}

run_step() {
    local desc="$1"
    shift

    if [ "${DRY_RUN:-false}" == "true" ]; then
        echo -e "  ${YELLOW}▷ ${desc}${RESET}"
        echo -e "      $*"
        return 0
    fi

    "$@"
    local rc=$?

    if [ "${rc}" -ne 0 ]; then
        print_status "${desc}" fail
        exit "${rc}"
    fi

    print_status "${desc}" ok
}

create_run_cgexec() {
    local script="${SCRIPT_DIR}/run_cgexec.sh"

    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Generate run_cgexec.sh" skip
        return 0
    fi

    cat > "${script}" <<EOF
#!/usr/bin/env bash
export LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib:\$LIBRARY_PATH
export LD_LIBRARY_PATH=${TERAHEAP_REPO}/allocator/lib/:\$LD_LIBRARY_PATH
export PATH=${TERAHEAP_REPO}/allocator/include/:\$PATH
export C_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include/:\$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=${TERAHEAP_REPO}/allocator/include/:\$CPLUS_INCLUDE_PATH
"\$@"
EOF

    chmod +x "${script}"
}

set_cpu_perf_mode() {
    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Set CPU governor to performance" skip
        return 0
    fi

    sudo "${SCRIPT_DIR}/cpu_perf.sh" -p
}

set_cpu_sched_mode() {
    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Restore CPU governor to schedutil" skip
        return 0
    fi

    sudo "${SCRIPT_DIR}/cpu_perf.sh" -s
}

download_system_util() {
    if [ -d "${SCRIPT_DIR}/system_util" ]; then
        return 0
    fi

    if [ "${DRY_RUN:-false}" == "true" ]; then
        print_status "Download system_util" skip
        return 0
    fi

    git clone \
        git@github.com:jackkolokasis/system_util.git \
        "${SCRIPT_DIR}/system_util"
}
