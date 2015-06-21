#!/bin/bash
/sbin/ethtool -K eth0 tso off gro off gso on
/sbin/ifconfig eth0 txqueuelen 5000
