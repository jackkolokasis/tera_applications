#!/usr/bin/env bash

# Check if directory argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

DIR="$1"
FILE="$DIR/0/stderr"

# Function to check for SIGSEGV in the output
check_segfault() {
  while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"SIGSEGV"* ]]; then
      echo "SIGSEGV detected. Invoking kill_processes.sh."
      ./kill_processes.sh
    fi
  done
}

# Start tailing the file and redirect stdout to a pipe
tail -f "$FILE" | check_segfault
