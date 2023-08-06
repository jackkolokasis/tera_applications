#!/usr/bin/env bash

#mdadm --stop /dev/md0
#mdadm --zero-superblock /dev/nvme0n1 /dev/nvme1n1

blkdiscard /dev/sdg
blkdiscard /dev/sdh
sudo mdadm --create --verbose /dev/md1 --level=stripe --chunk=1024 --raid-devices=2 /dev/sdg /dev/sdh

