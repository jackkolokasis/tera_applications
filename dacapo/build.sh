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

COMPILE_OUT="log.txt"

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

download_dacapo_benhcmarks() {
  wget https://download.dacapobench.org/chopin/dacapo-23.11-chopin.zip >> "${COMPILE_OUT}" 2>&1
  unzip dacapo-23.11-chopin.zip >> "${COMPILE_OUT}" 2>&1
}

download_dacapo_benhcmarks
retValue=$?
message="Download Dacapo benchmarks" 
check ${retValue} "${message}"
