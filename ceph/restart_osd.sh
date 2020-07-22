#!/usr/bin/env bash

for i in `xms-cli osd list|grep data-pool|awk '{print $4}'|awk -F '.' '{print $2}'`
do
  while [[ $(ceph health) != 'HEALTH_OK' ]]; do
    echo "$(ceph health)"
    sleep 2
  done
  echo "osd.$i"
  /usr/bin/ssh $(ceph osd find $i|grep -o 10.255.20...[0-9]) "systemctl restart ceph-osd@${i}"
done
