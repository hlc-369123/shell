#!/usr/bin/env bash

TEST_DB='db_list'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
mkdir -p /tmp/operations/net
rm -f /tmp/operations/net/*
if [ -f /tmp/operations/${TEST_DB} ];then
  for i in $(grep ',' /tmp/operations/${TEST_DB})
  do
    if [[ -n ${i} ]];then
      if [ $(echo $i |grep -o ','|wc -l) == '3' ];then
        echo ${i}|sed -e 's/,/ /g'|awk '{print $1 >>'${ADMIN_IP}'} {print $2 >>'${PUBLIC_IP}' {print $3 >>'${PRIVATE_IP} {print $4 >>'${GATEWAY_IP}'}'
      else
        for ip_list in $(echo ${i}|sed -e "s/,/ /g");do echo $ip_list 1>>${OTHER_IP};done
      fi
    else
      for i in $(cat /tmp/operations/${TEST_DB})
      do
        null #判断是否为ip，执行测试或者为自定义ip
        exit 0
      done
    fi
  done
else
  echo "not /tmp/operations/${TEST_DB}"&&exit 1
fi
