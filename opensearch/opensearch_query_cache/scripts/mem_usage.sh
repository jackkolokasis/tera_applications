#!/usr/bin/env bash
###################################################
#
# file: mem_usage.sh
#
# Track cgroup v2 memory usage while OpenSearch runs.
#
# Usage:
#   ./mem_usage.sh <output-file> [process-pattern]
#
###################################################

set -u

OUTPUT="${1:?usage: mem_usage.sh <output file> [process pattern]}"
PROC_PATTERN="${2:-org.opensearch.bootstrap.OpenSearch}"

NUM_OF_PROCS="${NUM_OF_PROCS:-1}"
CGROUP_PATH="${CGROUP_PATH:-/sys/fs/cgroup/memlim}"
INTERVAL="${INTERVAL:-1}"
START_TIMEOUT="${START_TIMEOUT:-600}"

mkdir -p "$(dirname "${OUTPUT}")"

waited=0

while [ "$(pgrep -fc -- "${PROC_PATTERN}")" -lt "${NUM_OF_PROCS}" ]; do
    sleep 1
    waited=$((waited + 1))

    if [ "${waited}" -ge "${START_TIMEOUT}" ]; then
        echo \
            "mem_usage.sh: timed out after ${START_TIMEOUT}s waiting for '${PROC_PATTERN}'" \
            >&2
        exit 1
    fi
done

if [ ! -d "${CGROUP_PATH}" ]; then
    echo "mem_usage.sh: cgroup ${CGROUP_PATH} not found" >&2
    exit 1
fi

if [ ! -r "${CGROUP_PATH}/memory.stat" ] || \
   [ ! -r "${CGROUP_PATH}/memory.current" ]
then
    echo "mem_usage.sh: missing cgroup v2 memory files under ${CGROUP_PATH}" >&2
    exit 1
fi

: > "${OUTPUT}"
echo "timestamp anon file current" >> "${OUTPUT}"

while pgrep -f -- "${PROC_PATTERN}" >/dev/null; do
    ts=$(date +%s)

    anon=$(
        awk '/^anon / { print $2; exit }' \
            "${CGROUP_PATH}/memory.stat" \
            2>/dev/null
    )

    file=$(
        awk '/^file / { print $2; exit }' \
            "${CGROUP_PATH}/memory.stat" \
            2>/dev/null
    )

    current=$(
        cat "${CGROUP_PATH}/memory.current" \
            2>/dev/null
    )

    echo \
        "${ts} ${anon:-0} ${file:-0} ${current:-0}" \
        >> "${OUTPUT}"

    sleep "${INTERVAL}"
done

exit 0
