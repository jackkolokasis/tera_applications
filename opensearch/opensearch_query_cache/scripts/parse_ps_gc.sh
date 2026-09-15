#!/usr/bin/env bash

set -u

GC_LOG="${1:-}"

if [[ -z "$GC_LOG" ]]; then
    echo "Usage: $0 <gc_log>"
    exit 1
fi

if [[ ! -f "$GC_LOG" ]]; then
    echo "Error: file not found: $GC_LOG"
    exit 1
fi

awk '
BEGIN {
    young_count = 0
    full_count = 0
    young_total = 0
    full_total = 0
}

# Match only final GC summary lines, not [gc,start] or [gc,phases]
/\[gc[[:space:]]*\].*GC\([0-9]+\) Pause Young/ {
    if (match($0, /GC\(([0-9]+)\)/, gc) &&
        match($0, /([0-9]+(\.[0-9]+)?)ms$/, t)) {

        gc_id = gc[1]
        time_ms = t[1] + 0

        printf "GC(%4d) Young: %10.3f ms\n", gc_id, time_ms

        young_total += time_ms
        young_count++
    }
}

/\[gc[[:space:]]*\].*GC\([0-9]+\) Pause Full/ {
    if (match($0, /GC\(([0-9]+)\)/, gc) &&
        match($0, /([0-9]+(\.[0-9]+)?)ms$/, t)) {

        gc_id = gc[1]
        time_ms = t[1] + 0

        printf "GC(%4d) Full : %10.3f ms\n", gc_id, time_ms

        full_total += time_ms
        full_count++
    }
}

END {
    print ""
    print "GC Summary"
    print "----------"

    printf "Young GC count : %d\n", young_count
    printf "Young GC time  : %.3f ms\n", young_total

    if (young_count > 0)
        printf "Young GC avg   : %.3f ms\n", young_total / young_count

    print ""

    printf "Full GC count  : %d\n", full_count
    printf "Full GC time   : %.3f ms\n", full_total

    if (full_count > 0)
        printf "Full GC avg    : %.3f ms\n", full_total / full_count

    print ""
    printf "Total GC time  : %.3f ms\n", young_total + full_total
}
' "$GC_LOG"
