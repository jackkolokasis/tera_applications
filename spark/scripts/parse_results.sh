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

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5

MAJOR_GC_PHASES_PLOT_TITLE=

# Print error/usage script message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo
    echo "      -d, --dir <path> 		Specify the directory for storing the results."
    echo "      -p, --plot <title>           	Specify the plot title for the breakdown of the major gc's phases execution time."
    echo "      -n, --num-executors <number>    Specify the number of executors."
    echo "      -g, --gc-threads <number>       Specify the number of gc threads."
    echo "      -t, --teraheap  		Enable TeraHeap."
    echo "      -s, --serialize  		Enable serialization/deserialization."
    echo "      -h, --help  			Display this help message and exit."
    echo
    exit 1
}

function parse_script_arguments() {
  local OPTIONS=d:p:n:g:tsh
  local LONGOPTIONS=dir:,plot:,num-executors:,gc-threads:,teraheap,serialize,help

  # Use getopt to parse the options
  local PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")

  # Check for errors in getopt
  if [[ $? -ne 0 ]]; then
    exit ${ERRORS[INVALID_OPTION]}
  fi

  # Evaluate the parsed options
  eval set -- "$PARSED"
  while true; do
    case "$1" in
    -d | --dir)
      RESULT_DIR="$2"
      shift 2
      ;;
    -p | --plot)
      MAJOR_GC_PHASES_PLOT_TITLE="$2"
      shift 2
      ;;
    -n | --num-executors)
      NUM_EXECUTORS="$2"
      shift 2
      ;;
    -g | --gc-threads)
      GC_THREADS="$2"
      shift 2
      ;;
    -t | --teraheap)
      TH=true
      shift
      ;;
    -s | --serialize)
      SER=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Programming error"
      exit ${ERRORS[PROGRAMMING_ERROR]} 
      ;;
    esac
  done
}

parse_script_arguments "$@"
: '
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
'
TOTAL_TIME=$(tail -n 1 ${RESULT_DIR}/total_time.txt | awk '{split($0,a,","); print a[3]}')
TOTAL_TIME_IN_MILLISECONDS=($(echo "$TOTAL_TIME * 1000" | bc))
MINOR_GC=()
MAJOR_GC=()
PHASE3_H2_COMPACT_MOVED_OBJECTS_PER_GC_THREAD=()
PHASE3_H2_COMPACT_MOVED_BYTES_PER_GC_THREAD=()
PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_ELAPSED_TIME=
PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_OPERATIONS=
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_ELAPSED_TIME=
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_OPERATIONS=
: '
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_ELAPSED_TIME=
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_OPERATIONS=
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_ELAPSED_TIME=
PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_OPERATIONS=
PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_ELAPSED_TIME=
PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_OPERATIONS=
'
#MINOR_GC_IN_MILLISECONDS=()
#MAJOR_GC_IN_MILLISECONDS=()

for ((i=0; i<NUM_EXECUTORS; i++))
do
  MINOR_GC+=($(tail -n 1 "${RESULT_DIR}"/jstat_${i}.txt | awk '{print $8}'))
  MAJOR_GC+=($(tail -n 1 "${RESULT_DIR}"/jstat_${i}.txt | awk '{print $10}'))
  # Convert to milliseconds and append to the arrays
  #MINOR_GC_IN_MILLISECONDS+=($(echo "$MINOR_GC * 1000" | bc))
  #MAJOR_GC_IN_MILLISECONDS+=($(echo "$MAJOR_GC * 1000" | bc))
done
for ((i=0; i<GC_THREADS; i++))
do
  PHASE3_H2_COMPACT_MOVED_OBJECTS_PER_GC_THREAD+=($(grep "H2_COMPACT_MOVED_OBJECTS_PER_GC_THREAD($i)" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }'))
  PHASE3_H2_COMPACT_MOVED_BYTES_PER_GC_THREAD+=($(grep "H2_COMPACT_MOVED_BYTES_PER_GC_THREAD($i)" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }'))
done

: '
# Initialize total execution time variables
total_minor_gc=0
total_major_gc=0

# Sum up the execution times in milliseconds for MINOR_GC
for time in "${MINOR_GC_IN_MILLISECONDS[@]}"
do
  total_minor_gc=$(echo "$total_minor_gc + $time" | bc)
done

# Sum up the execution times in milliseconds for MAJOR_GC
for time in "${MAJOR_GC_IN_MILLISECONDS[@]}"
do
  total_major_gc=$(echo "$total_major_gc + $time" | bc)
done
'
# Caclulate the overheads in TeraHeap card table traversal, marking and adjust phases
if [ $TH ]
then 
  H1_CT_TRAVERSAL=$(grep "H1_CT_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }')
  H2_CT_TRAVERSAL=$(grep "H2_CT_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }')
  # Phase 1: H1_MARKING_PHASE
  PHASE1=$(grep "H1_MARKING_PHASE" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  # Phase 2: H1_SUMMARY_PHASE
  PHASE2_H1_SUMMARY=$(grep "H1_SUMMARY_PHASE" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE2_H2_PRECOMPACT=$(grep "H2_PRECOMPACT" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  #PHASE2=$(echo "$PHASE2_H1_SUMMARY + $PHASE2_H2_PRECOMPACT" | bc)
  # Phase 3: Combined H2_COMPACT_PHASE, H2_ADJUST_BWD_REF_PHASE, H1_ADJUST_ROOTS_PHASE
  PHASE3_H2_COMPACT=$(grep "H2_COMPACT_PHASE" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_ELAPSED_TIME=$(grep "H2_COMPACT_BUFFER_INSERT_ELAPSED_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_OPERATIONS=$(grep "H2_COMPACT_TOTAL_BUFFER_INSERT_OPERATIONS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_ELAPSED_TIME=$(grep "H2_COMPACT_FLUSH_BUFFER_ELAPSED_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_OPERATIONS=$(grep "H2_COMPACT_TOTAL_FLUSH_BUFFER_OPERATIONS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END { print sum }')
  : '
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_ELAPSED_TIME=$(grep "H2_COMPACT_FLUSH_BUFFER_FRAGMENTATION_ELAPSED_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_OPERATIONS=$(grep "H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_OPERATIONS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_ELAPSED_TIME=$(grep "H2_COMPACT_FLUSH_BUFFER_NOFREESPACE_ELAPSED_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_OPERATIONS=$(grep "H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_OPERATIONS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_ELAPSED_TIME=$(grep "H2_COMPACT_ASYNC_REQUEST_ELAPSED_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_OPERATIONS=$(grep "H2_COMPACT_TOTAL_ASYNC_REQUEST_OPERATIONS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END { print sum }')
  '
  #H2_COMPACT_GROUP_REGION_LOCK_TIME=$(grep "H2_COMPACT_GROUP_REGION_LOCK_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }')
  #H2_COMPACT_REGION_LOCK_TIME=$(grep "H2_COMPACT_REGION_LOCK_TIME" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $5 } END {print sum }')
  PHASE3_H2_ADJUST_BWD_REF=$(grep "H2_ADJUST_BWD_REF" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  PHASE3_H1_ADJUST_ROOTS=$(grep "H1_ADJUST_ROOTS" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  #PHASE3=$(echo "scale=10; $PHASE3_H2_COMPACT + $PHASE3_H2_ADJUST_BWD_REF + $PHASE3_H1_ADJUST_ROOTS" | bc)
  PHASE3=$(echo "${PHASE3_H2_COMPACT} + ${PHASE3_H2_ADJUST_BWD_REF} + ${PHASE3_H1_ADJUST_ROOTS}" | bc -l)
  # Phase 4: H1_COMPACT_PHASE
  PHASE4=$(grep "H1_COMPACT" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
  # Phase 5: H2_CLEAR_FWD_TABLE_PHASE
  PHASE5=$(grep "H2_CLEAR_FWD_TABLE" "${RESULT_DIR}"/teraHeap.txt | awk '{ sum += $4 } END { print sum }')
fi

# Caclulate the serialziation/deserialization overhead

for ((i=0; i<NUM_EXECUTORS; i++))
do
  ../../util/FlameGraph/flamegraph.pl "${RESULT_DIR}"/serdes_"${i}".txt > "${RESULT_DIR}"/profile.svg
  #../../util/FlameGraph/flamegraph.pl "${RESULT_DIR}"/serdes_"${i}".txt > "${RESULT_DIR}"/profile.html

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

  NET_TIME=$(echo "${TOTAL_TIME} - ${MINOR_GC[$i]} - ${MAJOR_GC[$i]}" | bc -l)
  SD_SAMPLES=$(echo "${SER_SAMPLES} + ${DESER_SAMPLES}" | bc -l)
  SERDES+=($(echo "${SD_SAMPLES} * ${NET_TIME} / ${APP_THREAD_SAMPLES}" | bc -l))
done

{
  echo "COMPONENT,TIME(ms)"               
  #echo "TOTAL_TIME,${TOTAL_TIME}"
  : '
  for ((i=0; i<NUM_EXECUTORS; i++))
  do
    echo "MINOR_GC,${MINOR_GC[$i]}"
    echo "MAJOR_GC,${MAJOR_GC[$i]}"
  done
  '
  printf "TOTAL_TIME : %.3f\n" "${TOTAL_TIME_IN_MILLISECONDS}" 
  printf "MINOR_GC   : %.3f\n" "$(echo "$MINOR_GC * 1000" | bc)" 
  printf "MAJOR_GC   : %.3f\n" "$(echo "$MAJOR_GC * 1000" | bc)" 
  printf "H1_CT_TRAVERSAL_MINOR_GC : %.3f\n" "${H1_CT_TRAVERSAL}"
  printf "H2_CT_TRAVERSAL_MINOR_GC : %.3f\n" "${H2_CT_TRAVERSAL}" 
  # Print the total time for each phase 
  printf "[Phase 1] H1_MARKING_PHASE   : %.3f\n" "$PHASE1"
  printf "[Phase 2] H1_SUMMARY_PHASE   : %.3f\n" "$PHASE2_H1_SUMMARY"
  printf "[Phase 2] H2_PRECOMPACT      : %.3f\n" "$PHASE2_H2_PRECOMPACT"
  printf "[Phase 3] H2_COMPACT + H2_ADJUST_BWD_REF + H1_ADJUST_ROOTS: %.3f\n" "$PHASE3"
  printf "          H2_COMPACT         : %.3f\n" "${PHASE3_H2_COMPACT}"
  #printf "          GROUP_REGION_LOCK  : %.3f\n" "${H2_COMPACT_GROUP_REGION_LOCK_TIME}"
  #printf "          REGION_LOCK        : %.3f\n" "${H2_COMPACT_REGION_LOCK_TIME}"
  printf "          H2_ADJUST_BWD_REF  : %.3f\n" "${PHASE3_H2_ADJUST_BWD_REF}"
  printf "          H1_ADJUST_ROOTS    : %.3f\n" "${PHASE3_H1_ADJUST_ROOTS}"
  printf "[Phase 4] H1_COMPACT         : %.3f\n" "$PHASE4"
  printf "[Phase 5] H2_CLEAR_FWD_TABLE : %.3f\n" "$PHASE5"

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
: '
if [ $TH ]
then
  {
    # Print the total time for each phase into a .csv file
    printf "TOTAL_TIME,%.3f\n" "$(echo "$TOTAL_TIME")"
    printf "MINOR_GC,%.3f\n" "$(echo "$MINOR_GC")"
    printf "MAJOR_GC,%.3f\n" "$(echo "$MAJOR_GC")"
    printf "H1_MARKING_PHASE,%.3f\n" "$PHASE1"
    printf "H1_SUMMARY_PHASE,%.3f\n" "$PHASE2_H1_SUMMARY"
    printf "H2_COMPACT, %.3f\n" "${PHASE3_H2_COMPACT}"
    printf "H2_ADJUST_BWD_REF,%.3f\n" "${PHASE3_H2_ADJUST_BWD_REF}"
    printf "H1_ADJUST_ROOTS,%.3f\n" "${PHASE3_H1_ADJUST_ROOTS}"
    printf "H1_COMPACT,%.3f\n" "$PHASE4"
    printf "H2_CLEAR_FWD_TABLE,%.3f\n" "$PHASE5"
  } >> "${RESULT_DIR}"/$MAJOR_GC_PHASES_PLOT_TITLE.csv
 
  #source flexheap/bin/activate 
  python3 gc_execution_time_plot.py $MAJOR_GC_PHASES_PLOT_TITLE "${RESULT_DIR}"/$MAJOR_GC_PHASES_PLOT_TITLE.csv "${RESULT_DIR}"
  #deactivate

  {
    grep "TOTAL_TRANS_OBJ" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "TOTAL_FORWARD_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "TOTAL_BACK_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "DUMMY" "${RESULT_DIR}"/teraHeap.txt | awk '{sum+=$6} END {print "DUMMY_OBJ_SIZE(GB),"sum*8/1024/1024}'
    grep "DISTRIBUTION" "${RESULT_DIR}"/teraHeap.txt |tail -n 1 |awk '{print $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12" " $13 " " $14 " " $15}'
  } >> "${RESULT_DIR}"/statistics.csv
fi
'
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

if [ $TH ]
then
  {
    # Print the total time for each phase into a .csv file
    printf "TOTAL_TIME,%.3f\n" "$(echo "$TOTAL_TIME")"
    printf "MINOR_GC,%.3f\n" "$(echo "$MINOR_GC")"
    printf "MAJOR_GC,%.3f\n" "$(echo "$MAJOR_GC")"
    printf "H1_MARKING_PHASE,%.3f\n" "$(echo "$PHASE1 / 1000" | bc -l )"
    printf "H1_SUMMARY_PHASE,%.3f\n" "$(echo "$PHASE2_H1_SUMMARY / 1000" | bc -l )"
    printf "H2_COMPACT, %.3f\n" "$(echo "$PHASE3_H2_COMPACT / 1000" | bc)"
    printf "H2_ADJUST_BWD_REF,%.3f\n" "$(echo "$PHASE3_H2_ADJUST_BWD_REF / 1000" | bc -l )"
    printf "H1_ADJUST_ROOTS,%.3f\n" "$(echo "$PHASE3_H1_ADJUST_ROOTS / 1000" | bc -l )"
    printf "H1_COMPACT,%.3f\n" "$(echo "$PHASE4 / 1000" | bc -l )"
    printf "H2_CLEAR_FWD_TABLE,%.3f\n" "$(echo "$PHASE5 / 1000" | bc -l )"
    printf "USR_TIME, %.3f\n" "${USR_TIME}"
    printf "SYS_TIME, %.3f\n" "${SYS_TIME}"
    printf "IOW_TIME, %.3f\n" "${IOW_TIME}"
  } >> "${RESULT_DIR}"/$MAJOR_GC_PHASES_PLOT_TITLE.csv

  #source flexheap/bin/activate 
  python3 gc_execution_time_plot.py $MAJOR_GC_PHASES_PLOT_TITLE "${RESULT_DIR}"/$MAJOR_GC_PHASES_PLOT_TITLE.csv "${RESULT_DIR}"
  #deactivate

  {
    grep "TOTAL_TRANS_OBJ" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "TOTAL_FORWARD_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "TOTAL_BACK_PTRS" "${RESULT_DIR}"/teraHeap.txt | awk '{print $3","$5}'
    grep "DUMMY" "${RESULT_DIR}"/teraHeap.txt | awk '{sum+=$6} END {print "DUMMY_OBJ_SIZE(GB),"sum*8/1024/1024}'
    grep "DISTRIBUTION" "${RESULT_DIR}"/teraHeap.txt |tail -n 1 |awk '{print $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12" " $13 " " $14 " " $15}'
  } >> "${RESULT_DIR}"/statistics.csv
fi

if [ $TH ]
then
  {
    for ((i=0; i<GC_THREADS; i++))
    do
        echo "H2_COMPACT_MOVED_OBJECTS_PER_GC_THREAD($i),${PHASE3_H2_COMPACT_MOVED_OBJECTS_PER_GC_THREAD[$i]}"
	echo "H2_COMPACT_MOVED_BYTES_PER_GC_THREAD($i),${PHASE3_H2_COMPACT_MOVED_BYTES_PER_GC_THREAD[$i]}"
    done
  } >> "${RESULT_DIR}"/h2_objects_statistics.csv
fi

if [ $TH ]
then
{
      echo "H2_COMPACT_TOTAL_BUFFER_INSERT_ELAPSED_TIME,${PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_ELAPSED_TIME}"
      echo "H2_COMPACT_TOTAL_BUFFER_INSERT_OPERATIONS,${PHASE3_H2_COMPACT_TOTAL_BUFFER_INSERT_OPERATIONS}"
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_ELAPSED_TIME,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_ELAPSED_TIME}"
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_OPERATIONS,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_OPERATIONS}"
      : '
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_ELAPSED_TIME,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_ELAPSED_TIME}"
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_OPERATIONS,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_FRAGMENTATION_OPERATIONS}"
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_ELAPSED_TIME,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_ELAPSED_TIME}"
      echo "H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_OPERATIONS,${PHASE3_H2_COMPACT_TOTAL_FLUSH_BUFFER_NOFREESPACE_OPERATIONS}"
      echo "H2_COMPACT_TOTAL_ASYNC_REQUEST_ELAPSED_TIME,${PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_ELAPSED_TIME}"
      echo "H2_COMPACT_TOTAL_ASYNC_REQUEST_OPERATIONS,${PHASE3_H2_COMPACT_TOTAL_ASYNC_REQUEST_OPERATIONS}"
'
  } >> "${RESULT_DIR}"/h2_operations_statistics.csv
fi
