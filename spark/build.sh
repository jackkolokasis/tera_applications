#!/usr/bin/env bash

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ $1 -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]"
    fi
}

./spark-3.2.1/compile.sh > compile.out 2>&1
retValue=$?
message="Build Spark" 
check ${retValue} "${message}"

./spark-bench/bin/build-all.sh >> compile.out 2>&1
retValue=$?
message="Build Spark Benchmarks" 
check ${retValue} "${message}"
