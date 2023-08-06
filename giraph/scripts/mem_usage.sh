#!/usr/bin/env bash

###################################################
#
# file: myjstat.sh
#
# @Author:  Iacovos G. Kolokasis
# @Version: 19-01-2021
# @email:   kolokasis@ics.forth.gr
#
# @brief    This script tracks the memory usage 
###################################################

# Output file name
OUTPUT=$1        
NUM_OF_EXECUTORS=$2

# Number of executors
numOfExecutors=0

# Wait here until the executors are launched
while [ ${numOfExecutors} -lt "${NUM_OF_EXECUTORS}" ] 
do
    # Calculate number of executors running
    numOfExecutors=$(jps |grep -c "YarnChild")
done

watch -n 1 "free -g >> ${OUTPUT}" &
