#!/bin/bash

signal=$1

env(){
if [ $# != 1 ]
then
echo 'parameter error!!'
exit 1
fi
hostname=$HOSTNAME
vdfile=$1
date=$(date +%m%d%H%M%S)
path='/opt/vdtest/'
if [ ! -d $path ]
then
mkdir $path
fi
}

if [[ $signal == 'start' ]]
then
env $2
sar -C 1 >> ${path}${hostname}-$vdfile-cpu-$date.log&
sar -r 1 >> ${path}${hostname}-$vdfile-memory-$date.log&
sar -d -p 1 >> ${path}${hostname}-$vdfile-disk-$date.log&
sar -n DEV 1 >> ${path}${hostname}-$vdfile-network-$date.log&
sleep 5
elif [[ $signal == 'stop' ]]
then
for i in $(ps -ef|grep sar|grep -v grep|awk '{print $2}')
do kill -9 $i
done
fi
