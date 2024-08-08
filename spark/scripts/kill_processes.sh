#!/usr/bin/env bash

pgrep -f serdes.sh | xargs kill -9
pgrep -f mem_usage.sh | xargs kill -9
pgrep -f jstat.sh | xargs kill -9

# Run the jps command and get the list of process IDs
process_ids=$(jps | awk '{print $1}')

# Check if there are any process IDs returned by jps
if [ -z "$process_ids" ]; then
	echo "No Java processes found."
	exit 0
fi

# Iterate over each process ID and kill it
for pid in $process_ids; do
	echo "Killing process ID $pid"
	kill -9 $pid
done

echo "All Java processes killed."
