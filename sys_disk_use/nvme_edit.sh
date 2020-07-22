#!/bin/bash

nvme list|awk '/nvme/ {print $1,"\t"$11$12}'
read -p "'nvme format $i -l 1', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in `nvme list|awk '/nvme/ {print $1}'`;do echo $i;nvme format $i -l 1;sleep 2;done
fi


read -p "'parted -s $i mklabel gpt', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in `nvme list|awk '/nvme/ {print $1}'`;do echo $i;parted -s $i mklabel gpt;sleep 2;done
fi


read -p "'parted -s $i mkpart journal xfs 2048s 10G', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in `nvme list|awk '/nvme/ {print $1}'`;do echo $i;parted -s $i mkpart journal xfs 2048s 10G;sleep 2;done
  lsblk
fi


read -p "'cat /sys/class/nvme/nvme${i}/nvme${i}n1/queue/scheduler', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in {0..1};do echo -e "\n";echo "nvme${i}n1";cat /sys/class/nvme/nvme${i}/nvme${i}n1/queue/scheduler;done
fi


read -p "'echo "mq-deadline >" >/sys/class/nvme/nvme${i}/nvme${i}n1/queue/scheduler', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in {0..1};do echo -e "\n";echo "nvme${i}n1";echo "mq-deadline >" >/sys/class/nvme/nvme${i}/nvme${i}n1/queue/scheduler;done
fi


read -p "'cat /sys/class/nvme/nvme${i}/nvme${i}n1/queue/nr_requests', type 'y' : " hond_on
if [[ "$hond_on" != 'y' ]];then
  continue
else
  for i in {0..1};do echo -e "\n";echo "nvme${i}n1";cat /sys/class/nvme/nvme${i}/nvme${i}n1/queue/nr_requests;done
fi
