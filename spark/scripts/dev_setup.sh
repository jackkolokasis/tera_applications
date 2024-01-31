#!/usr/bin/env bash

###################################################
#
# file: dev_setup.sh
#
# @Author:   Iacovos G. Kolokasis
# @Version:  19-09-2021
# @email:    kolokasis@ics.forth.gr
#
# Prepare the devices for the experiments
#
###################################################

USER=$(whoami)

# Check if the last command executed succesfully
#
# if executed succesfully, print SUCCEED
# if executed with failures, print FAIL and exit
check () {
    if [ $1 -ne 0 ]
    then
        echo -e "  $2 \e[40G [\e[31;1mFAIL\e[0m]"
        exit
    else
        echo -e "  $2 \e[40G [\e[32;1mSUCCED\e[0m]"
    fi
}

# Print error/usage script message
usage() {
    echo
    echo "Usage:"
    echo -n "      $0 [option ...] [-k][-h]"
    echo
    echo "Options:"
    echo "      -t  Run experiments with teraCache"
    echo "      -f  Run experiments with fastmap"
    echo "      -s  File size for TeraCache"
    echo "      -d  List for devices. First device for TeraCache and second for Suffle"
    echo "      -u  Unmount all devices"
    echo "      -h  Show usage"
    echo

    exit 1
}

destroy_th() {
	if [ "$1" ]
	then
		sudo umount "${MNT_SHFL}"
		# Check if the command executed succesfully
		retValue=$?
		message="Unmount ${DEVICES[1]}" 
		check ${retValue} "${message}"

		#rm -rf "${MNT_FMAP}"/file.txt
		rm -rf "${MNT_H2}"/H2.txt
		# Check if the command executed succesfully
		retValue=$?
		message="Remove TeraHeap H2 backed-file" 
		check ${retValue} "${message}"
	else
		#rm -rf "${MNT_SHFL}"/file.txt
		rm -rf "${MNT_SHFL}"/H2.txt
		# Check if the command executed succesfully
		retValue=$?
		message="Remove TeraHeap H2 backed-file" 
		check ${retValue} "${message}"
		
		#sudo umount /mnt/spark
		sudo umount "${MNT_SHFL}"
		# Check if the command executed succesfully
		retValue=$?
		message="Unmount ${DEVICES[0]}" 
		check ${retValue} "${message}"
	fi
}

destroy_ser() {
	sudo umount "${MNT_SHFL}"
	# Check if the command executed succesfully
	retValue=$?
	message="Unmount $DEV_SHFL" 
	check ${retValue} "${message}"
}
    
# Check for the input arguments
while getopts ":s:d:tfuh" opt
do
    case "${opt}" in
		t)
			TH=true
			;;
		s)
			TH_FILE_SZ=${OPTARG}
			;;
		d)
			DEVICE_SHFL=${OPTARG}
			;;
		u)
			DESTROY=true
			;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# Unmount TeraCache device
if [ $DESTROY ]
then
	if [ $TH ]
	then
		destroy_th $FASTMAP
	else
		destroy_ser
	fi
	exit
fi

# Setup Device 
#if ! mountpoint -q /mnt/datasets
if ! mountpoint -q $MNT_BENCHMARK_DATASETS
then
	#sudo mount /dev/sdb /mnt/datasets
	#sudo chown kolokasis /mnt/datasets
	sudo mount $DEV_BENCHMARK_DATASETS $MNT_BENCHMARK_DATASETS
	sudo chown $USER $MNT_BENCHMARK_DATASETS
fi

# Setup TeraCache device
if [ $TH ]
then
		#if ! mountpoint -q /mnt/spark
		if ! mountpoint -q $MOUNT_POINT_SHUFFLE
		then
			#sudo mount /dev/${DEVICE_SHFL} /mnt/spark
			sudo mount $DEV_SHFL $MOUNT_POINT_SHUFFLE
			# Check if the command executed succesfully
			retValue=$?
			message="Mount ${DEV_SHFL} for shuffle and TeraCache" 
			check ${retValue} "${message}"
			#sudo chown "$USER" /mnt/spark
			sudo chown "$USER" $MOUNT_POINT_SHUFFLE
			# Check if the command executed succesfully
			retValue=$?
			#message="Change ownerships /mnt/spark" 
			message="Change ownerships $MOUNT_POINT_SHUFFLE" 
			check ${retValue} "${message}"
		fi

		#cd /mnt/spark || exit
		cd $MOUNT_POINT_SHUFFLE || exit
		# if the file does not exist then create it
		if [ ! -f H2.txt ]
		then
			fallocate -l ${TH_FILE_SZ}G H2.txt
			# Check if the command executed succesfully
			retValue=$?
			message="Create ${TH_FILE_SZ}G file for TeraCache" 
			check ${retValue} "${message}"
		else
			rm H2.txt
			# Check if the command executed succesfully
			retValue=$?
			message="Remove ${TH_FILE_SZ}G file" 
			check ${retValue} "${message}"
			
			fallocate -l ${TH_FILE_SZ}G H2.txt
			# Check if the command executed succesfully
			retValue=$?
			message="Create ${TH_FILE_SZ}G file for TeraCache" 
			check ${retValue} "${message}"
		fi
		cd -
	fi
else
	#if mountpoint -q /mnt/spark
	if mountpoint -q $MOUNT_POINT_SHUFFLE
	then
		exit
	fi
	#sudo mount /dev/${DEVICE_SHFL} /mnt/spark
	sudo mount $DEV_SHFL $MOUNT_POINT_SHUFFLE
	# Check if the command executed succesfully
	retValue=$?
	message="Mount $DEV_SHFL $MOUNT_POINT_SHUFFLE" 
	check ${retValue} "${message}"
		
	#sudo chown kolokasis /mnt/spark
	sudo chown $USER $MOUNT_POINT_SHUFFLE
	# Check if the command executed succesfully
	retValue=$?
	message="Change ownerships $MOUNT_POINT_SHUFFLE" 
	check ${retValue} "${message}"
fi
exit
