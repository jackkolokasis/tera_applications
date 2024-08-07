#!/usr/bin/env bash

###################################################
#
# file: build.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Building Lucene and benchmarks
#
###################################################

. ./config.sh
# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ "$1" -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]"
    fi
}

build_lucene() {
  wget https://github.com/apache/lucene/archive/refs/tags/releases/lucene/9.6.0.tar.gz >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Download Lucene" 
  check ${retValue} "${message}"

  tar xf 9.6.0.tar.gz >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Extract Lucene" 
  check ${retValue} "${message}"

  mv lucene-releases-lucene-9.6.0/ lucene9.6.0/

  cd lucene9.6.0/ || exit
  ./gradlew >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Lucene" 
  check ${retValue} "${message}"

  ./gradlew jar >> "${COMPILE_OUT}" 2>&1
  retValue=$?
  message="Build Lucene Jar file" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}
      
# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-h]"
    echo
    echo "Options:"
    echo "      -a  Compile and build both Lucene and benchmarks"
    echo "      -l  Compile and build only Lucene"
    echo "      -b  Compile and build only benchmarks"
    echo "      -h  Show usage"
    echo

    exit 1
}

# These benchmarks are from Shoaib
build_benchmarks() {
  # Fix the classpath in the makefile
  local jar_files=""

  cd ./lucene9.6.0 

  # Append jar files
  for j in $(find "$(pwd)" -name "*.jar"); do
    if [ -z "$jar_files" ]; then
      jar_files="$j"
    else
      jar_files="$jar_files:$j"
    fi
  done

  cd - > /dev/null || exit

  # Change the classpath variable in the make file
  sed -i "s|^CLASSPATH=.*|CLASSPATH=${jar_files}|" ${BENCHMARKS_REPO}/Makefile

  cd ${BENCHMARKS_REPO}

  make all >> "${COMPILE_OUT}" 2>&1 
  retValue=$?
  message="Compile benchmarks" 
  check ${retValue} "${message}"

  cd - > /dev/null || exit
}
  
echo "-----------------------------------"
echo "Compilation output messages are here: ${COMPILE_OUT}"
echo "-----------------------------------"
echo 

# Check for the input arguments
while getopts "albh" opt
do
  case "${opt}" in
    a)
      build_lucene
      build_benchmarks
      ;;
    l)
      build_lucene
      ;;
    b)
      build_benchmarks
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done
