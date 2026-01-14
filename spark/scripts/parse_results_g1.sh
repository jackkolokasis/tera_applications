###################################################
#
# file: parse_results.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  20-01-2021 
# @email:    kolokasis@ics.forth.gr
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
    echo "      -d  Directory with results"
    echo "      -t  Enable TeraHeap"
    echo "      -s  Enable serialization/deserialization"
    echo "      -h  Show usage"
    echo

    exit 1
}


# Check for the input arguments
while getopts "d:n:tsah" opt
do
    case "${opt}" in
        s)
            SER=true
            ;;
        t)
            TH=true
            ;;
        d)
            RESULT_DIR="${OPTARG}"
            ;;
        n)
            NUM_EXECUTORS="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

TOTAL_TIME=$(tail -n 1 ${RESULT_DIR}/total_time.txt | awk '{split($0,a,","); print a[3]}')

FULL_GC_C=$(grep -c "Pause Full.*ms" ${RESULT_DIR}/gc.log)
FULL_GC_T=$(grep "Pause Full" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

YOUNG_GC_C=$(grep "Young.*ms" ${RESULT_DIR}/gc.log | grep -vc "(Mixed)")
YOUNG_GC_T=$(grep "Young" ${RESULT_DIR}/gc.log | grep -v "(Mixed)" | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

MIX_GC_C=$(grep -c "(Mixed).*ms" ${RESULT_DIR}/gc.log)
MIX_GC_T=$(grep "(Mixed)" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

CM_TIME=$(tail -n 1 "${RESULT_DIR}"/jstat_0.txt | awk '{print $12}')

#remark phase cm stw
REMARK_GC_C=$(grep "Pause Remark" ${RESULT_DIR}/gc.log | wc -l)
REMARK_GC_T=$(grep "Pause Remark" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

#cleanup phase cm stw
CLEANUP_GC_C=$(grep "Pause Cleanup" ${RESULT_DIR}/gc.log | wc -l)
CLEANUP_GC_T=$(grep "Pause Cleanup" ${RESULT_DIR}/gc.log | grep -oP '(\d+\.\d+)ms$' | awk '{ sum += $1 } END { print sum/1000.0 }')

CM_STW=$(echo "${REMARK_GC_T} + ${CLEANUP_GC_T}" | bc -l) 

STW=$(echo "${FULL_GC_T} + ${YOUNG_GC_T} + ${MIX_GC_T} + ${CM_STW}" | bc -l) 
STW_WITH_CM=$(echo "${CM_STW} + ${STW}" | bc -l) 

# CACHE_MISSES=$(grep "cache-misses" ${RESULT_DIR}/perf | awk '{print $1}' | sed 's/,//g' )

# G1_YOUNG_GC=$(tail -n 1 "${RESULT_DIR}"/jstat_0.txt | awk '{print $8}')
# G1_FULL_GC=$(tail -n 1 "${RESULT_DIR}"/jstat_0.txt | awk '{print $10}')

TOTAL_GC_TIME=$(tail -n 1 "${RESULT_DIR}"/jstat_0.txt | awk '{print $13}')

MINOR_GC=()
MAJOR_GC=()

for ((i=0; i<NUM_EXECUTORS; i++))
do
  MINOR_GC+=($(tail -n 1 "${RESULT_DIR}"/jstat_${i}.txt | awk '{print $8}'))
  MAJOR_GC+=($(tail -n 1 "${RESULT_DIR}"/jstat_${i}.txt | awk '{print $10}'))
done

# Caclulate the overheads in TeraHeap card table traversal, marking and adjust phases
if [ $TH ]
then
  TC_CT_TRAVERSAL=$(grep "TC_CT" "${RESULT_DIR}"/teraHeap.txt     | awk '{print $5}' | awk '{ sum += $1 } END {print sum }')
  HEAP_CT_TRAVERSAL=$(grep "HEAP_CT" "${RESULT_DIR}"/teraHeap.txt | awk '{print $5}' | awk '{ sum += $1 } END {print sum }')
fi

PHASE1=$(grep "Phase 1.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE2=$(grep "Phase 2.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE3=$(grep "Phase 3.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')
PHASE4=$(grep "Phase 4.*ms" "${RESULT_DIR}"/gc.log | awk '{print $NF}' | sed 's/ms//' | awk '{ sum += $1 } END {print sum/1000.0 }')

# Caclulate the serialziation/deserialization overhead

for ((i=0; i<NUM_EXECUTORS; i++))
do

  # FIXME: I don't know why this is fixing flamegraph
  sleep 10
  
  ../../util/FlameGraph/flamegraph.pl "${RESULT_DIR}/serdes_${i}.txt"  > "${RESULT_DIR}"/profile.svg

  SER_SAMPLES=$(grep "org/apache/spark/serializer/KryoSerializationStream.writeObject" "${RESULT_DIR}"/profile.svg \
    | awk '{print $2}' \
    | sed 's/,//g' | sed 's/(//g' \
    | awk '{sum+=$1} END {print sum}')
  DESER_SAMPLES=$(grep "org/apache/spark/serializer/KryoDeserializationStream.readObject" "${RESULT_DIR}"/profile.svg \
    | awk '{print $2}' \
    | sed 's/,//g' |sed 's/(//g' \
    | awk '{sum+=$1} END {print sum}')
  APP_THREAD_SAMPLES=$(grep -w "java/lang/Thread.run" "${RESULT_DIR}"/profile.svg \
    | awk '{print $2}' \
    | sed 's/,//g' \
    | sed 's/(//g' \
    | head -n 1)

  # PS
  # NET_TIME=$(echo "${TOTAL_TIME} - ${MINOR_GC[$i]} - ${MAJOR_GC[$i]}" | bc -l)
  # SD_SAMPLES=$(echo "${SER_SAMPLES} + ${DESER_SAMPLES}" | bc -l)
  # SERDES+=($(echo "${SD_SAMPLES} * ${NET_TIME} / ${APP_THREAD_SAMPLES}" | bc -l))

  # G1
  NET_TIME=$(echo "${TOTAL_TIME} - ${TOTAL_GC_TIME}" | bc -l)
  SD_SAMPLES=$(echo "${SER_SAMPLES} + ${DESER_SAMPLES}" | bc -l)
  SERDES+=($(echo "${SD_SAMPLES} * ${NET_TIME} / ${APP_THREAD_SAMPLES}" | bc -l))
done

{
  echo "COMPONENT,TIME(s)"               
  echo "TOTAL_TIME,${TOTAL_TIME}"
  echo "TOTAL_GC,$TOTAL_GC_TIME ($STW)"

  # for ((i=0; i<NUM_EXECUTORS; i++))
  # do
  #   echo "MINOR_GC,${MINOR_GC[$i]}"
  #   echo "MAJOR_GC,${MAJOR_GC[$i]}"
  # done

  echo "YOUNG_GC,$YOUNG_GC_C,$YOUNG_GC_T"
  echo "CM_TIME,$CM_STW ($CM_TIME)"
  echo "MIXED_GC,$MIX_GC_C,$MIX_GC_T"
  echo "FULL_GC,$FULL_GC_C,$FULL_GC_T"

  echo "TC_MINOR_GC,${TC_CT_TRAVERSAL}"
  echo "HEAP_MINOR_GC,${HEAP_CT_TRAVERSAL}"

  echo "PHASE1_FGC,${PHASE1}"
  echo "PHASE2_FGC,${PHASE2}"
  echo "PHASE3_FGC,${PHASE3}"
  echo "PHASE4_FGC,${PHASE4}"

  for ((i=0; i<NUM_EXECUTORS; i++))
  do
    echo "SERDES,${SERDES[$i]}"
  done

} >> "${RESULT_DIR}"/result.csv

{
  echo "SER_SAMPLES,${SER_SAMPLES}"
  echo "DESER_SAMPLES,${DESER_SAMPLES}"
  echo "APP_THREAD_SAMPLES,${APP_THREAD_SAMPLES}"
} >> "${RESULT_DIR}"/serdes.csv

# if [ $TH ]
# then
#   {
#     grep "TOTAL_TRANS_OBJ" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
#     grep "TOTAL_FORWARD_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
#     grep "TOTAL_BACK_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
#     grep "DUMMY" "${RESULT_DIR}"/teraHeap.txt | awk '{sum+=$6} END {print "DUMMY_OBJ_SIZE(GB),"sum*8/1024/1024}'
#     grep "DISTRIBUTION" "${RESULT_DIR}"/teraHeap.txt |tail -n 1 |awk '{print $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12" " $13 " " $14 " " $15}'
#   } >> "${RESULT_DIR}"/statistics.csv
# fi

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
  echo "USR_TIME,${USR_TIME}"
  echo "SYS_TIME,${SYS_TIME}"
  echo "IOW_TIME,${IOW_TIME}"
} >> "${RESULT_DIR}"/result.csv

{
  if [ $TH ]
  then
    echo

    MIXGC_H2_ALLOC_TIME=$(grep "ALLOC" "${RESULT_DIR}"/teraHeap.txt | grep "MIXED" | awk '{ sum+=$4 } END { print sum/1000.0 }')
    echo "MIXGC_H2_ALLOC_TIME,$MIXGC_H2_ALLOC_TIME"

    PHASE2_H2_ALLOC_TIME=$(grep "ALLOC" "${RESULT_DIR}"/teraHeap.txt | grep "FULL" | awk '{ sum+=$4 } END { print sum/1000.0 }')
    echo "PHASE2_H2_ALLOC_TIME,$PHASE2_H2_ALLOC_TIME"
  fi

  echo
  echo "$TOTAL_TIME $TOTAL_GC_TIME $YOUNG_GC_T $CM_STW $MIX_GC_T $FULL_GC_T $PHASE1 $PHASE2 $PHASE3 $PHASE4 ${SERDES[0]}"
} >> "${RESULT_DIR}"/result.csv
