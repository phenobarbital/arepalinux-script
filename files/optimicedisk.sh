#!/bin/bash
# script para optimizar el acceso a disco de sistemas en noop o deadline
# autor: jesus lara jesuslara@gmail.com
DISKS=( sda )
# parameters
SCHEDULER="deadline"
ROTATIONAL=0
QUEUEDEPTH=975
RQAFFINITY=0
BLOCKDEV=16384
# iteration
for DISK in $DISKS
do
        echo "change I/O elevator to $SCHEDULER"
        echo $SCHEDULER > /sys/block/$DISK/queue/scheduler
        echo "optimice server disk block size to $BLOCKDEV"
        /sbin/blockdev --setra $BLOCKDEV /dev/$DISK
        echo "set queue depth to $QUEUEDEPTH"
        /bin/echo $QUEUEDEPTH > /sys/block/$DISK/queue/nr_requests
        # turn off rotational (RAID/SSD/NAS/HBA related)
        /bin/echo $ROTATIONAL > /sys/block/$DISK/queue/rotational
        # read ahead and sectors read by disk
        /bin/echo "8192" > /sys/block/$DISK/queue/read_ahead_kb
        /bin/echo "4096" > /sys/block/$DISK/queue/max_sectors_kb
        # fifo batch reduce seeks
        # /bin/echo 1 > /sys/block/$DISK/queue/iosched/fifo_batch
        echo "set rq affinity to $RQAFFINITY"
        /bin/echo 1 > /sys/block/$DISK/queue/rq_affinity
        # enable write-caching
        /sbin/hdparm -a1 -A1 -W1 -M251 /dev/$DISK
done
echo "done."
