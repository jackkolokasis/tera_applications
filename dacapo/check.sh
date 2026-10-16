#!/usr/bin/env bash

# BENCHMARKS=( "avrora" "batik" "biojava" "eclipse" "fop" "graphchi" "jme" "jython" "kafka" "luindex" "lusearch" "pmd" "sunflow" "xalan" "zxing" "tradebeans" "tradesoap" "cassandra" "h2" "h2o" "spring" )
#
# BASE_URL="https://raw.githubusercontent.com/dacapobench/dacapobench/main/benchmarks/bms"
#
# for bench in "${BENCHMARKS[@]}"; do
#     result=$(curl -s "${BASE_URL}/${bench}/stats-nominal.yml" | grep "^GML:")
#     if [ -n "$result" ]; then
#         mb=$(echo "$result" | awk -F',' '{print $2}' | tr -d ' ')
#         echo "$bench: ${mb} MB"
#     else
#         echo "$bench: no large size"
#     fi
# done

###################################################
# Print memory-related nominal statistics for each DaCapo benchmark, taken
# from the upstream stats-nominal.yml files. Each line of those files is:
#   KEY: [score/10, value, rank, min, median, max, description]
# and we print only the "value" field.
#
# Columns:
#   AOL  90th-percentile object size, in bytes
#   ARA  Allocation rate, in bytes per microsecond (equivalently MB/s)
#   GML  Minimum heap size, in MB, for the "large" input size
#        (with compressed pointers); "-" means there is no large size
#   GLK  Memory leakage: percent growth in live heap at the 10th
#        iteration relative to the 1st (0 = no leak)
#   GTO  Memory turnover: total bytes allocated divided by the
#        minimum heap size (how many times the heap is "recycled")
###################################################

BASE_URL="https://raw.githubusercontent.com/dacapobench/dacapobench/main/benchmarks/bms"
BENCHMARKS=( "avrora" "batik" "biojava" "eclipse" "fop" "graphchi" "jme" "jython" "kafka" "luindex" "lusearch" "pmd" "sunflow" "xalan" "zxing" "tradebeans" "tradesoap" "cassandra" "h2" "h2o" "spring" )

echo "Columns:"
echo "  AOL(B)    90th-percentile object size (bytes)"
echo "  ARA(B/us) Allocation rate (bytes/usec)"
echo "  GML(MB)   Minimum heap size for the large input (MB, compressed pointers)"
echo "  GLK(%)    Memory leakage: live-heap growth at 10th vs 1st iteration (%)"
echo "  GTO       Memory turnover: total allocated bytes / minimum heap size"
echo "  -         Value not reported for this benchmark"
echo

printf "%-15s %9s %9s %9s %9s %9s\n" "Benchmark" "AOL(B)" "ARA(B/us)" "GML(MB)" "GLK(%)" "GTO"
echo "-------------------------------------------------------------------"

for bench in "${BENCHMARKS[@]}"; do
    yaml=$(curl -s "${BASE_URL}/${bench}/stats-nominal.yml")
    aol=$(echo "$yaml" | grep "^AOL:" | awk -F',' '{print $2}' | tr -d ' ')
    ara=$(echo "$yaml" | grep "^ARA:" | awk -F',' '{print $2}' | tr -d ' ')
    gml=$(echo "$yaml" | grep "^GML:" | awk -F',' '{print $2}' | tr -d ' ')
    glk=$(echo "$yaml" | grep "^GLK:" | awk -F',' '{print $2}' | tr -d ' ')
    gto=$(echo "$yaml" | grep "^GTO:" | awk -F',' '{print $2}' | tr -d ' ')
    printf "%-15s %9s %9s %9s %9s %9s\n" "$bench" "${aol:--}" "${ara:--}" "${gml:--}" "${glk:--}" "${gto:--}"
done
