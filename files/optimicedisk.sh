#!/bin/bash
# script para optimizar el acceso a disco de sistemas con noop o deadline
# autor: Jesus Lara <jesuslara@gmail.com>
disks=( sda )
# parameters
SCHEDULER="deadline"
ROTATIONAL=0
QUEUEDEPTH=256
BLOCKDEV=16384
# iteration
for DISK in "${disks[@]}"
do
        echo "Change I/O elevator to $SCHEDULER"
        echo $SCHEDULER > /sys/block/$DISK/queue/scheduler
        echo "Optimice server disk block size to $BLOCKDEV"
        /sbin/blockdev --setra $BLOCKDEV /dev/$DISK
        echo "Set queue depth to $QUEUEDEPTH"
        /bin/echo $QUEUEDEPTH > /sys/block/$DISK/queue/nr_requests
        echo "Disabling NCQ on $DISK"
        echo 1 > /sys/block/$DISK/device/queue_depth
        # turn off rotational (only on RAID/SSD/NAS/HBA related)
        #/bin/echo $ROTATIONAL > /sys/block/$DISK/queue/rotational
        # read ahead and sectors read by disk
        /bin/echo "8192" > /sys/block/$DISK/queue/read_ahead_kb
        /bin/echo "4096" > /sys/block/$DISK/queue/max_sectors_kb
        if [ "$SCHEDULER" == 'deadline' ]; then
                # fifo batch reduce seeks
                /bin/echo 32 > /sys/block/$DISK/queue/iosched/fifo_batch
	fi
        # enable write-caching and readahead (performance boost)
        /sbin/hdparm -a512 -A1 -W1 /dev/$DISK
done
echo "done."
