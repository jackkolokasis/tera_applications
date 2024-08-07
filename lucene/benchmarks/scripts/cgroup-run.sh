# runs the specified program with the specified cgroup (specified by same arguments that were given to
# cgroup-create.sh)

# note: does not require SUDO

# check for the right argument number
if [ $# -lt 3 ]; then
	echo "usage: cgroup-create.sh [cgroup_name] [memory_limit] [program_to_run]"
	exit
fi

MEMORY_LIMIT_ARG=$2
CGROUP_NAME="$1.$MEMORY_LIMIT_ARG"
PROGRAM=$3

cgexec -g memory:/${CGROUP_NAME} $PROGRAM