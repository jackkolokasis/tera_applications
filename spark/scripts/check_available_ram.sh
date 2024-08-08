#!/usr/bin/env bash

# Get the available RAM in megabytes
available_ram=$(free -m | awk '/Mem:/ { print $7 }')

echo "Available RAM: ${available_ram} MB"

