#!/bin/bash

fastest_drive=""
fastest_speed=0

for drive in $(lsblk -d -o NAME -n); do
    if [[ $drive =~ ^sd ]]; then
        speed=$(sudo hdparm -Tt /dev/$drive 2>/dev/null | grep "Timing buffered disk reads" | awk '{print $11}')
        echo "Drive /dev/$drive speed: $speed MB/s"
        if (( $(echo "$speed > $fastest_speed" | bc -l) )); then
            fastest_speed=$speed
            fastest_drive="/dev/$drive"
        fi
    fi
done

echo "The fastest drive is $fastest_drive with a speed of $fastest_speed MB/s"
