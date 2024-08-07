#!/usr/bin/env bash

# Function to create RAID
# Chunk is in terms of KB
create() {
  sudo mdadm --create --verbose "$RAID_DEV" --level=0 --raid-devices="$NUM_DEVICES" ${DEVICES} --chunk=1024
  sudo mkfs.xfs "$RAID_DEV"
  sudo mkdir -p "$MOUNT_DIR"
  sudo mount "$RAID_DEV" "$MOUNT_DIR"
}

# Function to destroy RAID
destroy() {
  sudo umount "$MOUNT_DIR"
  sudo mdadm --stop "$RAID_DEV"
  sudo mdadm --remove "$RAID_DEV"
  sudo mdadm --zero-superblock ${DEVICES}
}

# Function to display usage information
usage() {
  local exit_code=$1
  # Define color codes
  bold=$(tput bold)
  green=$(tput setaf 2)
  reset=$(tput sgr0)

  echo "${bold}${green}Usage:${reset} $0 [-n num_devices] [-d devices] [-m mount_dir] [-r raid_dev] [create|destroy] [-h]"
  echo "${bold}${green}Options:${reset}"
  echo "  -n num_devices    Number of devices to use"
  echo "  -d devices        List of devices"
  echo "  -m mount_point    RAID mount directory"
  echo "  -r raid_device    RAID device (e.g., /dev/md0)"
  echo "  -h                Display help message"
  echo "${bold}${green}Examples:${reset}"
  echo "  Create:  ./raid.sh -n 2 -d \"/dev/nvme0n1 /dev/nvme1n1\" -m /mnt/spark -r /dev/md2 create"
  echo "  Destroy: ./raid.sh -d \"/dev/nvme0n1 /dev/nvme1n1\" -m /mnt/spark -r /dev/md2 destroy"

  exit "$exit_code"
}

# Parse command line options
while getopts ":n:d:m:r:h" opt; do
  case ${opt} in
    n )
      NUM_DEVICES=$OPTARG
      ;;
    d )
      DEVICES=$OPTARG
      ;;
    m )
      MOUNT_DIR=$OPTARG
      ;;
    r )
      RAID_DEV=$OPTARG
      ;;
    h )
      usage 0
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      usage
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      usage
      exit 1
      ;;
  esac
done

# Shift the positional parameters to exclude processed options
shift $((OPTIND -1))

# Check if the number of arguments (excluding options) is correct
if [ "$#" -ne 1 ]; then
  echo "Invalid number of arguments"
  usage
  exit 1
fi

# Execute the specified command
case $1 in
  create)
    create
    ;;
  destroy)
    destroy
    ;;
  *)
    echo "Invalid command: $1"
    usage
    exit 1
    ;;
esac
