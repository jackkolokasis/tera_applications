#!/usr/bin/env bash

reset_stat() {
	echo 500  | sudo tee /proc/sys/vm/dirty_writeback_centisecs
	echo 3000 | sudo tee /proc/sys/vm/dirty_expire_centisecs
	echo 20   | sudo tee /proc/sys/vm/dirty_ratio
	echo 10   | sudo tee /proc/sys/vm/dirty_background_ratio
}

set_stat() {
	echo 500000 | sudo tee /proc/sys/vm/dirty_writeback_centisecs
	echo 500000 | sudo tee /proc/sys/vm/dirty_expire_centisecs
	echo 90		| sudo tee /proc/sys/vm/dirty_ratio
	echo 90 	| sudo tee /proc/sys/vm/dirty_background_ratio
}

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-h]"
    echo
    echo "Options:"
    echo "      -s  Set counters"
    echo "      -r  Reset Counters"
    echo "      -h  Show usage"
    echo

    exit 1
}

# Check for the input arguments
while getopts "srh" opt
do
    case "${opt}" in
        s)
			set_stat
			exit
            ;;
        r)
            reset_stat
			exit
            ;;
        h)
            usage
            exit
            ;;
	esac	
done
