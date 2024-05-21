#!/usr/bin/env bash

###################################################
#
# file: myjstat.sh
#
# @Author:  Iacovos G. Kolokasis
# @Version: 04-05-2018
# @email:   kolokasis@ics.forth.gr
#
# @brief    This script use jstat to monitor the
# Garbage Collection utilization from the JVM
# executor running in spark. Find out the proccess
# id of the executor from the jps and the execute
# the jstat.  All the informations are saved in an
# output file.
#
###################################################

# Output file name
OUTPUT=$1        

# Get the proccess id from the running
processId=""
numOfExecutors=0

# Loop until the count of "Main" in jps output is 1
while [ $(jps | grep -c "Main") -ne 1 ]; do
  # No op
  :
done

# Executors
processId=$(jps | grep "Main" | awk '{print $1}')

jstat -gcutil "${processId}" 1000 > "${OUTPUT}.txt" &
