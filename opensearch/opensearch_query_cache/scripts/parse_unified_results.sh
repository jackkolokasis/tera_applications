#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-.}"
OUTPUT_CSV="${2:-unified_results.csv}"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

# ------------------------------------------------------------
# Find every all_queries.csv
# ------------------------------------------------------------
while IFS= read -r -d '' file; do

    # --------------------------------------------------------
    # Determine configuration from path
    #
    # Important: check chipper before teraheap because paths
    # such as "results_chipper_teraheap_..." contain both.
    # --------------------------------------------------------
    case "$file" in
        *chipper*)
            config="chipper"
            ;;
        *onheap*|*on-heap*)
            config="onheap"
            ;;
        *teraheap*|*tera-heap*)
            config="teraheap"
            ;;
        *)
            echo "Warning: cannot determine configuration for: $file" >&2
            continue
            ;;
    esac

    echo "Parsing $file -> $config" >&2

    # --------------------------------------------------------
    # Extract columns by header name rather than assuming
    # fixed column numbers.
    # --------------------------------------------------------
    awk -F',' -v OFS=',' -v config="$config" '
        NR == 1 {
            for (i = 1; i <= NF; i++) {
                if ($i == "target_throughput_ops_s")
                    target_col = i
                else if ($i == "achieved_throughput_ops_s")
                    achieved_col = i
                else if ($i == "p99_latency_ms")
                    p99_col = i
            }

            if (!target_col || !achieved_col || !p99_col) {
                print "ERROR: required columns missing in file" > "/dev/stderr"
                exit 1
            }

            next
        }

        {
            print config, \
                  $target_col, \
                  $achieved_col, \
                  $p99_col
        }
    ' "$file" >> "$TMP_FILE"

done < <(
    find "$ROOT_DIR" \
        -type f \
        -path '*/csv/all_queries.csv' \
        -print0
)

# ------------------------------------------------------------
# Write header and sort by configuration + target throughput
# ------------------------------------------------------------
{
    echo "configuration,target_throughput_ops_s,achieved_throughput_ops_s,p99_latency_ms"

    sort \
        -t',' \
        -k1,1 \
        -k2,2n \
        "$TMP_FILE"
} > "$OUTPUT_CSV"

echo "Created: $OUTPUT_CSV"
