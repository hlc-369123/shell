#!/bin/bash

num=$(for i in `ls /var/run/ceph/ceph-osd.*.asok`;do ceph --admin-daemon $i perf dump | grep water;done|awk '{print $2}'|awk -F ',' '{print $1}'|awk '$1 > 3'|wc -l)
if [ ${num} -gt 1 ]
then
echo 'false'
else
echo 'true'
fi
