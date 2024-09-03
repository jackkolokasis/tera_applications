#!/usr/bin/env bash


main_dir="/mnt/$(who)"
subdirs=("fmap" "datasets" "spark" "spark_results")

# Define the device to mount (replace with your actual device, e.g., /dev/sdX1)
device="/dev/nvme0n1"

# Create the main directory
sudo mkdir -p "$main_dir"

# Create the subdirectories
for subdir in "${subdirs[@]}"; do
  sudo mkdir -p "$main_dir/$subdir"
done

# Mount the device to the main directory
sudo mount "$device" "$main_dir"

# Verify the mount
mount | grep "$device"

# Optionally, update /etc/fstab to mount automatically on boot
# echo "$device $main_dir ext4 defaults 0 2" | sudo tee -a /etc/fstab

