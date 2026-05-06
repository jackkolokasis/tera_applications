#!/usr/bin/env bash

# Declare an associative array used for error handling
declare -A ERRORS

# Define the "error" values
ERRORS[INVALID_OPTION]=1
ERRORS[INVALID_ARG]=2
ERRORS[OUT_OF_RANGE]=3
ERRORS[NOT_AN_INTEGER]=4
ERRORS[PROGRAMMING_ERROR]=5    

START=64
END=159
#START=
#END=
# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo "      ./cpu.sh [-e][-d][-h]"
    echo
    echo "Options:"
    echo "      -e  Enable cpus"
    echo "      -d  Disable cpus"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Enable Cores
enable_cores() {
    for i in `seq ${START} ${END}`;
    do
        sudo echo 1 > /sys/devices/system/cpu/cpu$i/online
    done
}

# Disable Cores
disable_cores() {
    for i in `seq ${START} ${END}`;
    do
        sudo echo 0 > /sys/devices/system/cpu/cpu$i/online
    done
}
: '
# Check for the input arguments
while getopts ":edh" opt
do
    case "${opt}" in
        e)
            enable_cores
            exit
            ;;
        d)
            disable_cores
            exit
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
function parse_script_arguments() {
  local OPTIONS=f:l:edh
  local LONGOPTIONS=first:,last:,enable,disable,help

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
    -f | --first)
      START="$2"
      shift 2
      ;;
    -l | --last)
      END="$2"
      shift 2
      ;;
    -e | --enable)
      enable_cores
      shift
      ;;
    -d | --disable)
      disable_cores
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
