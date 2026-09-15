#!/usr/bin/env bash
###################################################
#
# file: cpu_perf.sh
#
# Set/view Linux CPU frequency governors.
#
###################################################

set -u

usage() {
    cat <<EOF

Usage:
  ./cpu_perf.sh [-p|-s|-c|-v|-h]

Options:
  -p  Set performance governor
  -s  Set schedutil governor
  -c  Set conservative governor
  -v  View current governors
  -h  Show usage

EOF
    exit 1
}

shopt -s nullglob
GOVERNOR_FILES=(/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor)
shopt -u nullglob

if [ "${#GOVERNOR_FILES[@]}" -eq 0 ]; then
    echo "cpu_perf.sh: no cpufreq scaling_governor files found" >&2
    exit 1
fi

governor_supported() {
    local governor="$1"
    local available="${GOVERNOR_FILES[0]%/scaling_governor}/scaling_available_governors"

    if [ ! -r "${available}" ]; then
        return 0
    fi

    grep -qw -- "${governor}" "${available}"
}

set_governor() {
    local governor="$1"

    if ! governor_supported "${governor}"; then
        echo "cpu_perf.sh: governor '${governor}' is not supported on this host" >&2

        local available="${GOVERNOR_FILES[0]%/scaling_governor}/scaling_available_governors"
        if [ -r "${available}" ]; then
            echo -n "available governors: " >&2
            cat "${available}" >&2
        fi

        exit 1
    fi

    printf '%s\n' "${governor}" \
        | tee "${GOVERNOR_FILES[@]}" \
        >/dev/null

    echo "CPU governor: ${governor}"
}

view_governors() {
    local f

    for f in "${GOVERNOR_FILES[@]}"; do
        printf "%s: " "${f}"
        cat "${f}"
    done
}

while getopts ":pscvh" opt; do
    case "${opt}" in
        p)
            set_governor performance
            exit 0
            ;;
        s)
            set_governor schedutil
            exit 0
            ;;
        c)
            set_governor conservative
            exit 0
            ;;
        v)
            view_governors
            exit 0
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

usage
