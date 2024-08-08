#!/usr/bin/env bash

# Check if the user provided a size argument
if [ -z "$1" ]; then
  echo "Usage: $0 <size_in_GB>"
  exit 1
fi

# Size in GB
SIZE_IN_GB=$1

# Convert size to bytes
SIZE_IN_BYTES=$((SIZE_IN_GB * 1024 * 1024 * 1024))

# Get the page size in bytes
PAGE_SIZE=$(getconf PAGE_SIZE)

# Check if getconf command was successful
if [ $? -ne 0 ]; then
  echo "Error: Unable to determine the page size."
  exit 1
fi

# Calculate the required number of pages
NUM_PAGES=$((SIZE_IN_BYTES / PAGE_SIZE))

# Adjust vm.max_map_count for the session
sudo sysctl -w vm.max_map_count=$NUM_PAGES

# Verify the change
echo "Adjusted vm.max_map_count to $NUM_PAGES for the session."
