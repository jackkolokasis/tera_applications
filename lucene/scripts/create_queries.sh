#!/usr/bin/env bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 input_file1 input_file2 output_file num_queries"
    exit 1
fi

# Define input and output files
input_file1="$1"
input_file2="$2"
output_file="$3"
num_queries="$4"

# Initialize line counter
line_count=0

# Clear the output file if it exists
> "$output_file"

# Open the input files using file descriptors
exec 3<"$input_file1"
exec 4<"$input_file2"

# Function to read one line from each file and append to output
while [ "$line_count" -lt "$num_queries" ]; do
    if IFS= read -r line1 <&3; then
        echo "$line1" >> "$output_file"
        ((line_count++))
        if [ "$line_count" -ge "$num_queries" ]; then
            break
        fi
    fi
    if IFS= read -r line2 <&4; then
        echo "$line2" >> "$output_file"
        ((line_count++))
    fi
done

# Close the file descriptors
exec 3<&-
exec 4<&-

echo "Copied $line_count lines to $output_file"
