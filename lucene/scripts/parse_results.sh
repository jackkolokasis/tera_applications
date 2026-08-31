#!/usr/bin/env bash

###################################################
#
# file: parse_results.sh
#
# @Author:   Giannis Melidonis
# @Version:  29-04-2025 
# @email:    imel@ics.forth.gr
#
# Parse the results for the experiments
#
###################################################

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] "
    echo
    echo "Options:"
    echo "      -b  Benchmark name"
    echo "      -H  Heap size"
    echo "      -m  DRAM size"
    echo "      -t  Enable TeraHeap"
    echo "      -d  Directory with results"
    echo "      -h  Show usage"
    echo

    exit 1
}

fix_scientific() {
  local val="$1"
  local name="$2"
  if [[ "$val" =~ [eE][+-]?[0-9]+$ ]]; then
    val=$(awk -v x="$val" 'BEGIN { printf "%.14f", x }' | sed -E 's/0+$//; s/\.$/.0/')
    echo "[WARNING] scientific notation found ($name)! [$1] replaced with [$val]" >&2
  fi
  echo $val
}

# Check for the input arguments
while getopts "b:H:m:d:th" opt
do
    case "${opt}" in
        b)
          BENCH="${OPTARG}"
          ;;
        H)
          HEAP="${OPTARG}"
          ;;
        m)
          MEM_B="$OPTARG"
          ;;
        t)
          TH=true
          ;;
        d)
          RESULT_DIR="${OPTARG}"
          ;;
        h)
          usage
          ;;
        *)
          usage
          ;;
    esac
done

if [ $TH ]
then
  CONF="t"
else
  CONF="n"
fi

RUN_NAME=$(echo "${BENCH}_${CONF}_${HEAP}_${MEM_B}" | awk '{ print tolower($0) }')

# TOTAL_TIME=$(tail -n 1 ${RESULT_DIR}/total_time.txt | awk '{split($0,a,","); print a[3]}')
TOTAL_TIME=$(grep "Actual run" ${RESULT_DIR}/tmp.out | grep -oP "(\d+) ms" | awk '{ print $1 / 1000.0}')

FULL_GC_C=$(grep -c "Pause Full.*ms" ${RESULT_DIR}/gc.log)
FULL_GC_T=$(grep "Pause Full.*ms" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

YOUNG_GC_C=$(grep "Young.*ms" ${RESULT_DIR}/gc.log | grep -vc "(Mixed)\|(Prepare Mixed)")
YOUNG_GC_T=$(grep "Young.*ms" ${RESULT_DIR}/gc.log | grep -v "(Mixed)\|(Prepare Mixed)" | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

MIX_GC_C=$(grep -c "(Mixed).*ms\|(Prepare Mixed).*ms" ${RESULT_DIR}/gc.log)
MIX_GC_T=$(grep "(Mixed).*ms\|(Prepare Mixed).*ms" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

#remark phase cm stw
REMARK_GC_C=$(grep "Pause Remark" ${RESULT_DIR}/gc.log | wc -l)
REMARK_GC_T=$(grep "Pause Remark" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')
REMARK_GC_T=$(fix_scientific "$REMARK_GC_T" "REMARK_GC_T")

#cleanup phase cm stw
CLEANUP_GC_C=$(grep "Pause Cleanup" ${RESULT_DIR}/gc.log | wc -l)
CLEANUP_GC_T=$(grep "Pause Cleanup" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')
CLEANUP_GC_T=$(fix_scientific "$CLEANUP_GC_T" "CLEANUP_GC_T")

CM_STW=$(echo "${REMARK_GC_T} + ${CLEANUP_GC_T}" | bc -l) 

STW=$(echo "${FULL_GC_T} + ${YOUNG_GC_T} + ${MIX_GC_T} + ${CM_STW}" | bc -l) 

# Caclulate the overheads in TeraHeap card table traversal, marking and adjust phases
if [ $TH ]
then
  TC_CT_TRAVERSAL=$(grep "TC_CT" "${RESULT_DIR}"/teraheap.txt     | awk '{print $5}' | awk '{ sum += $1 } END {print sum }')
  HEAP_CT_TRAVERSAL=$(grep "HEAP_CT" "${RESULT_DIR}"/teraheap.txt | awk '{print $5}' | awk '{ sum += $1 } END {print sum }')
fi

PHASE1=$(grep "Phase 1.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE2=$(grep "Phase 2.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE3=$(grep "Phase 3.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE4=$(grep "Phase 4.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')

{
  echo "COMPONENT,TIME(s)"               
  echo "TOTAL_TIME,${TOTAL_TIME}"
  echo "TOTAL_GC,${STW}"

  echo "YOUNG_GC,$YOUNG_GC_C,$YOUNG_GC_T"
  echo "CM_TIME,$CM_STW"
  echo "MIXED_GC,$MIX_GC_C,$MIX_GC_T"
  echo "FULL_GC,$FULL_GC_C,$FULL_GC_T"

  echo "TC_MINOR_GC,${TC_CT_TRAVERSAL}"
  echo "HEAP_MINOR_GC,${HEAP_CT_TRAVERSAL}"

  echo "PHASE1_FGC,${PHASE1}"
  echo "PHASE2_FGC,${PHASE2}"
  echo "PHASE3_FGC,${PHASE3}"
  echo "PHASE4_FGC,${PHASE4}"

} >> "${RESULT_DIR}"/result.csv

# Read the Utilization from system.csv file
USR_UTIL_PER=$(grep "USR_UTIL" "${RESULT_DIR}"/system.csv |awk -F ',' '{print $2}')
SYS_UTIL_PER=$(grep "SYS_UTIL" "${RESULT_DIR}"/system.csv |awk -F ',' '{print $2}')
IO_UTIL_PER=$(grep "IOW_UTIL" "${RESULT_DIR}"/system.csv |awk -F ',' '{print $2}')

# Convert CPU utilization to time 
USR_TIME=$( echo "${TOTAL_TIME} * ${USR_UTIL_PER} / 100" | bc -l )
SYS_TIME=$( echo "${TOTAL_TIME} * ${SYS_UTIL_PER} / 100" | bc -l )
IOW_TIME=$( echo "${TOTAL_TIME} * ${IO_UTIL_PER} / 100" | bc -l )

{
  echo
  echo
  echo "CPU_COMPONENT,TIME(s)"
  echo "USR_TIME,${USR_TIME} (${USR_TIME})"
  echo "SYS_TIME,${SYS_TIME} (${SYS_TIME})"
  echo "IOW_TIME,${IOW_TIME} (${IOW_TIME})"
} >> "${RESULT_DIR}"/result.csv

# Lucene Results
USED_CACHE_SIZE=$(grep "Total memory used" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+)")
EVICT=$(grep "removed from cache" "$RESULT_DIR"/tmp.out | grep -oP "(\d+)")
PER99_9=$(grep "99.9th percentile" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+) mil" | awk '{ print $1 }')
PER99=$(grep "99th percentile" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+) mil" | awk '{ print $1 }')
PER95=$(grep "95th percentile" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+) mil" | awk '{ print $1 }')
PER90=$(grep "90th percentile" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+) mil" | awk '{ print $1 }')
PER50=$(grep "50th percentile" "$RESULT_DIR"/tmp.out | grep -oP "(\d+\.\d+) mil" | awk '{ print $1 }')
QPS=$(grep -oP "QPS (\d+\.\d+)" "$RESULT_DIR"/tmp.out | awk '{ print $2 }')

{
  echo
  echo "Lucene Stats"
  echo
  echo "USED_CACHE_SIZE(GB),$USED_CACHE_SIZE"
  echo "EVICT,$EVICT"
  echo "99.9th(ms),$PER99_9"
  echo "99th(ms),$PER99"
  echo "95th(ms),$PER95"
  echo "90th(ms),$PER90"
  echo "50th(ms),$PER50"
  echo "QPS,$QPS"
} >> "${RESULT_DIR}"/result.csv

{
  if [ $TH ]
  then
    echo

    MIXGC_H2_ALLOC_TIME=$(grep "ALLOC" "${RESULT_DIR}"/teraheap.txt | grep "MIXED" | awk '{ sum+=$4 } END { print sum/1000.0 }')
    echo "MIXGC_H2_ALLOC_TIME,$MIXGC_H2_ALLOC_TIME"

    PHASE2_H2_ALLOC_TIME=$(grep "ALLOC" "${RESULT_DIR}"/teraheap.txt | grep "FULL" | awk '{ sum+=$4 } END { print sum/1000.0 }')
    echo "PHASE2_H2_ALLOC_TIME,$PHASE2_H2_ALLOC_TIME"
  fi

  echo
  echo "$RUN_NAME $TOTAL_TIME $STW $YOUNG_GC_T $CM_STW $MIX_GC_T $FULL_GC_T $PHASE1 $PHASE2 $PHASE3 $PHASE4 $USED_CACHE_SIZE $EVICT $PER99_9 $PER99 $PER95 $PER90 $PER50 $QPS"
} >> "${RESULT_DIR}"/result.csv
