#!/usr/bin/env bash
###################################################
#
# file: build.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  18-07-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Download dacapo benchmarks
#
###################################################

COMPILE_OUT="${COMPILE_OUT:-build.log}"

# Check if the last command executed successfully
#
# if executed successfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ "$1" -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit 1
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCEED\e[0m]"
    fi
}

download_dacapo_benchmarks() {
    local zip_file="dacapo-23.11-chopin.zip"
    local url="https://download.dacapobench.org/chopin/${zip_file}"

    wget "${url}" >> "${COMPILE_OUT}" 2>&1
    check $? "Download Dacapo benchmarks zip"

    unzip "${zip_file}" >> "${COMPILE_OUT}" 2>&1
    check $? "Unzip Dacapo benchmarks"
}

download_dacapo_benchmarks
