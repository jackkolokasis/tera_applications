#!/usr/bin/env bash

###################################################
#
# file: monitor_perf_warnings.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  14-08-2024
# @email:    kolokasis@ics.forth.gr
#
# @brief: Script to monitor dmesg for "perf: interrupt took too long" 
# warnings during a program's execution
#
###################################################

OUTPUT=$1        

# Function to get the timestamp of the last dmesg entry
get_last_dmesg_timestamp() {
    dmesg | tail -1 | awk '{print $1}' | tr -d '[]'
}

# Function to check for specific warnings in dmesg since the last timestamp
check_dmesg_warnings() {
    dmesg | awk -v last_ts="$last_dmesg_timestamp" '{gsub(/[\[\]]/, "", $1); if ($1 > last_ts) print $0}' | grep "perf: interrupt took too long"
}

# Record the last dmesg timestamp before starting the program
last_dmesg_timestamp=$(get_last_dmesg_timestamp)

# Loop until the workload starts
while [ $(jps | grep -c -E "dacapo") -ne 1 ]; do
  # No op
  :
done

program_pid=$(jps | grep -E "dacapo" | awk '{print $1}')

# Inform the user
echo "Running your program with PID $program_pid. Monitoring dmesg for warnings..." > ${OUTPUT}

# Initial sleep to give the program some time to start
sleep 2

# Monitor dmesg for the warnings while the program is running
while kill -0 "$program_pid" 2> /dev/null; do
    warnings=$(check_dmesg_warnings)
    if [[ -n "$warnings" ]]; then
        echo "Warning detected in dmesg:" >> ${OUTPUT}
        echo "$warnings" >> ${OUTPUT}
        # Update the last timestamp to only show new messages next
        # time
        last_dmesg_timestamp=$(get_last_dmesg_timestamp)
    fi
    sleep 5  # Check every 5 seconds
done

echo "Program has finished running. Final check for warnings..." >> ${OUTPUT}
final_warnings=$(check_dmesg_warnings)
if [[ -n "$final_warnings" ]]; then
    echo "Final warning(s) detected in dmesg:" >> ${OUTPUT}
    echo "$final_warnings" >> ${OUTPUT}
fi
