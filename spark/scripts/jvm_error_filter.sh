#!/usr/bin/env bash

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[PROGRAMMING_ERROR]=3
ERRORS[JVM_ERROR]=4
ERRORS[SYSTEM_ERROR]=5

# Define the base directory where the OOM and IOException subdirectories are located.
# Adjust this path to match your actual directory structure.
WORK_PATH=""
BENCHMARK_PATH=""
PATTERN=""
USE_PATTERN=false
# Function to display usage message
function usage() {
  echo "Search a file or a directory for failed execution logs of Spark. Identify java heap OutOfMemory and IOException errors and move any findings into the directories OOM and IOException respectively."
  echo
  echo "Usage: $0 [options]"
  echo "Options:"
  echo
  echo "  -w, --work <path>             Specify a path to be searched for a SIGSEGV crash. eg. /spare/perpap/tera_applications/spark/spark-3.3.0/work/app-20240219160335-0000"
  echo "  -b, --benchmark <path>        Specify a path to be searched for OOM or IOException errors. The path may be a file or a directory."
  echo "                                eg. /spare/perpap/spark_results/FLEXHEAP/LinearRegression"
  echo "  -d, --delete <pattern>        Specify a search 'pattern' to be used for deleting matching files."
  echo "  -h, --help                    Display this help message and exit."
  echo
  echo "Examples:"
  echo
  echo "./jvm_error_filter.sh -b /spare/perpap/spark_results/FLEXHEAP/LinearRegression"
  echo "./jvm_error_filter.sh -b /spare/perpap/spark_results/FLEXHEAP/LinearRegression/run0/conf0/tmp_out.txt"
  echo "./jvm_error_filter.sh -b /spare/perpap/spark_results/FLEXHEAP/LinearRegression -d 14-07"
  echo "./jvm_error_filter.sh -w /spare/perpap/tera_applications/spark/spark-3.3.0/work/app-20240219160335-0000 -b /spare/perpap/spark_results/FLEXHEAP/LinearRegression"
  echo "./jvm_error_filter.sh -w /spare/perpap/tera_applications/spark/spark-3.3.0/work/app-20240219160335-0000 -b /spare/perpap/spark_results/FLEXHEAP/LinearRegression/run0/conf0/tmp_out.txt"
}

function parse_script_arguments() {
  local OPTIONS=w:b:d:h
  local LONGOPTIONS=work:,benchmark:,delete:,help

  # Use getopt to parse the options
  PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")

  # Check for errors in getopt
  if [[ $? -ne 0 ]]; then
    return ${ERRORS[INVALID_OPTION]} 2>/dev/null || exit ${ERRORS[INVALID_OPTION]}
  fi

  # Evaluate the parsed options
  eval set -- "$PARSED"

  while true; do
    case "$1" in
    -w | --work)
      WORK_PATH="$2"
      shift 2
      ;;
    -b | --benchmark)
      BENCHMARK_PATH="$2"
      shift 2
      ;;
    -d | --delete)
      PATTERN="$2"
      USE_PATTERN=true
      shift 2
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
      return ${ERRORS[PROGRAMMING_ERROR]} 2>/dev/null || exit ${ERRORS[PROGRAMMING_ERROR]} # This will return if sourced, and exit if run as a standalone script
      ;;
    esac
  done
}

function on_detect_pattern_delete_benchmark_results() {
  # Convert date_pattern to a comparable format
  local date_pattern=$(date -d "$(echo "$PATTERN" | sed 's/\(..\)-\(..\)-\(....\)-\(..\):\(..\):\(..\)/\3-\2-\1 \4:\5:\6/')" +%Y%m%d%H%M%S 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "Invalid date pattern. Please use the format DD-MM-YYYY-HH:MM:SS."
    return 1
  fi

  find "$BENCHMARK_PATH" -mindepth 1 | while read -r directory; do
    basename=$(basename "$directory")

    if [[ "$basename" =~ ([0-9]{2})-([0-9]{2})-([0-9]{4})-([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
      directory_date="${BASH_REMATCH[3]}${BASH_REMATCH[2]}${BASH_REMATCH[1]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
      if [[ "$directory_date" -lt "$date_pattern" ]]; then
        echo "Removing: $BENCHMARK_PATH/$basename"
        rm -rf $BENCHMARK_PATH/$basename
      fi
    fi
  done
}

function on_detect_handle_error() {
  errorPattern="$1" # The error pattern to search for
  appLogsDir="$2"   # The directory which contains logs of an application
  filePath="$3"     # The file in which to search
  errorDir="$4"     # The OOM or IOException directory
  # Check if the file exists

  if [ ! -f "$appLogsDir$filePath" ]; then
    echo "The file $appLogsDir$filePath does not exist."
    return 1
  fi

  # Search for the error pattern in the file
  grep -qF "$errorPattern" $appLogsDir$filePath
  if [ $? -eq 0 ]; then
    # If the error pattern is found, move the subdirectory to the corresponding error directory.
    echo "Error '$errorPattern' found in $filePath."
    mv "${appLogsDir}" "${errorDir}"
    echo "Moved ${appLogsDir} to ${errorDir}"
  fi
}

# Function to handle JVM errors based on predefined patterns.
function handle_jvm_errors() {
  # Define an associative array for error types and their corresponding search patterns.
  declare -A error_patterns=(
    [SIGSEGV]="gdb"
    [OOM]="OutOfMemory"
    [IOException]="IOException: No space left on device"
  )

  # Define an array to store the names of directories to skip.
  local skip_dirs=("SIGSEGV" "OOM" "IOException")
  # Define a variable to store the base directory which contains SIGSEGV, OOM, IOException subdirectories.
  local base_dir=""

  if [[ -f "$BENCHMARK_PATH" ]]; then
    base_dir=$(dirname "$BENCHMARK_PATH")
  elif [[ -d "$BENCHMARK_PATH" ]]; then
    base_dir="$BENCHMARK_PATH"
  else
    echo "No path given"
    exit
  fi

  # Loop through the error types and their patterns.
  for error_type in "${!error_patterns[@]}"; do
    # Define the directory where subdirectories with specific errors will be moved.
    # This creates directories like 'SIGSEGV', 'OOM' and 'IOException' in the parent directory of base_dir.
    local error_dir="${base_dir}/${error_type}"

    # Create the error directory if it does not exist.
    mkdir -p "${error_dir}"

    if [[ $error_type == "SIGSEGV" ]]; then
      #echo "checking $INPUT_PATH for SIGSEGV"
      if [[ ! -z $WORK_PATH ]]; then
        if [[ $(basename $WORK_PATH) == app* ]]; then
          if grep -q "${error_patterns[$error_type]}" "${WORK_PATH}/0/stderr"; then
            # If the error pattern is found, move the subdirectory to the corresponding error directory
            echo "Found crash on $WORK_PATH"
            cp -r "${WORK_PATH}" "${error_dir}"
            echo "Copied ${WORK_PATH} to ${error_dir}"
          fi
        fi
      fi
    else
      # Navigate to the base directory.
      #cd "${base_dir}" || exit

      if [[ -f "$BENCHMARK_PATH" ]]; then
        on_detect_handle_error "${error_patterns[$error_type]}" "$BENCHMARK_PATH" "${error_dir}"
      else
        # Navigate to the base directory.
        cd "${base_dir}" || exit

        # Loop through each subdirectory in the base directory.
        for dir in */; do
          # Skip directories that are meant for sorted errors.
          for skip_dir in "${skip_dirs[@]}"; do
            if [[ "${dir}" == "${skip_dir}/" ]]; then
              continue 2 # Skip this directory and continue with the next iteration of the outer loop.
            fi
          done
          #echo "Search in dir:$(realpath $dir)"

          on_detect_handle_error "${error_patterns[$error_type]}" ${dir} "run0/conf0/tmp_out.txt" "${error_dir}"
          : '
                    # Check if the file run0/conf0/tmp_out.txt exists and contains the specific error pattern.
                    if grep -q "${error_patterns[$error_type]}" "${dir}run0/conf0/tmp_out.txt" ; then
                        # If the error pattern is found, move the subdirectory to the corresponding error directory.
                        mv "${dir}" "${error_dir}"
                        echo "Moved ${dir} to ${error_dir}"
                    fi
                    '
        done
      fi
    fi
  done
}

parse_script_arguments "$@"

# Check if the benchmark path is not empty
if [[ -z "$BENCHMARK_PATH" ]]; then
  echo "No benchmark path provided."
  echo
  usage
elif [[ "$PATTERN" ]]; then
  on_detect_pattern_delete_benchmark_results
else
  handle_jvm_errors
fi
