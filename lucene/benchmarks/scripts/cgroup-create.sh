#!/bin/bash

# creates a cgroup with memory limit specified and name specified. the memory limit is automatically included
# in the new cgroup's name for convenience. the user specified by "username" is given permissions to the cgroup
# so they can use cgexec on it.
# note: requires SUDO permissions to run

MEMORY_LIMIT_ARG=$2
CGROUP_NAME="$1.$MEMORY_LIMIT_ARG"
USERNAME=$3

# check for the right argument number
if [ $# -lt 3 ]; then
	echo "usage: cgroup-create.sh [cgroup_name] [memory_limit] [username]"
	exit
fi

#  STEP1. PREP CGROUP
# Parse the memory limit argument into bytes
MEMORY_LIMIT_UNIT="${MEMORY_LIMIT_ARG: -1}"
if [[ "$MEMORY_LIMIT_UNIT" == "M" || "$MEMORY_LIMIT_UNIT" == "m" ]]; then
  MEMORY_LIMIT=$(( ${MEMORY_LIMIT_ARG::-1} * 1024 * 1024 ))
elif [[ "$MEMORY_LIMIT_UNIT" == "G" || "$MEMORY_LIMIT_UNIT" == "g" ]]; then
  MEMORY_LIMIT=$(( ${MEMORY_LIMIT_ARG::-1} * 1024 * 1024 * 1024 ))
else
  MEMORY_LIMIT="$MEMORY_LIMIT_ARG"
fi

# Create a new cgroup with a unique name

sudo cgcreate -a $USERNAME -t $USERNAME -g memory:/${CGROUP_NAME}

# Set the memory limit for the cgroup
sudo cgset -r memory.limit_in_bytes=${MEMORY_LIMIT} ${CGROUP_NAME}

echo "cgroup $CGROUP_NAME created"