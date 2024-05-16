#!/usr/bin/env bash

###################################################
#
# file: run.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  19-04-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: 
#
###################################################

# Print error/usage script message
usage() {
  local exit_code=$1

  echo
  echo "Usage:"
  echo -n "      $0 [option ...] [-h]"
  echo
  echo "Options:"
  echo "      -e  Export runtime variables"
  echo "      -r  Profile application (e.g., $0 -p <processId> -o <outputPath> -r)"
  echo "      -f  Generate flamegraphs (e.g., $0 -o <outputPath> -f)"
  echo "      -o  Output Path"
  echo "      -h  Show usage"
  echo

  exit "$exit_code"
}

## Export runtime variables
export_variables() {
  sudo sh -c 'echo -1 >/proc/sys/kernel/perf_event_paranoid' >> /dev/null 2>&1
  sudo sh -c 'echo 0 >/proc/sys/kernel/kptr_restrict' >> /dev/null 2>&1
}

##
# Profile application
#
profile_app() {
  local exec_id=$1
  local output_path=$2
  ./async-profiler/profiler.sh -d 40000 -i 10ms -o collapsed "${exec_id}" > "${output_path}/profile.txt" 2>/dev/null &
}

generate_flamegraphs() {
  local output_path=$1
  ./FlameGraph/flamegraph.pl "${output_path}"/profile.txt > "${output_path}"/profile.svg
}

check_arguments() {
  for arg in "$@"
  do
    if [ -z "$arg" ]
    then
      usage
    fi
  done
}
      
download_async_profiler() {
  if [ ! -d async-profiler ]
  then
    wget https://github.com/async-profiler/async-profiler/releases/download/v2.9/async-profiler-2.9-linux-x64.tar.gz >> /dev/null 2>&1 
    tar xf async-profiler-2.9-linux-x64.tar.gz >> /dev/null 2>&1 
    mv async-profiler-2.9-linux-x64 async-profiler
  fi
}
      
download_async_profiler

# Check for the input arguments
while getopts ":p:ofreh" opt
do
  case "${opt}" in
    e)
      export_variables
      ;;
    p)
      PROCESS_ID=${OPTARG}
      ;;
    o)
      OUTPUT_PATH=${OPTARG}
      ;;
    r)
      check_arguments "$PROCESS_ID" "$OUTPUT_PATH"
      profile_app "$PROCESS_ID" "$OUTPUT_PATH"
      ;;
    f)
      check_arguments "$OUTPUT_PATH"
      generate_flamegraphs "$OUTPUT_PATH"
      ;;
    h)
      usage 0
      ;;
    *)
      usage 1
      ;;
  esac
done

exit 0
