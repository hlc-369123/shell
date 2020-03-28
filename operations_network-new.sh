#!/usr/bin/env bash

TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
RED_COLOUR="\033[31m"
RES="\033[0m"
#mkdir -p /tmp/operations/net
#rm -f /tmp/operations/net/*

CHECK_NETWORK(){
for i in $(cat $1)
do
  LOCAL_IP=$(ip a|grep $i|awk '{print $2}'|sed 's/\/[0-9]*//g')
  if [[ -n ${LOCAL_IP} ]];then
    for y in $(cat $1)
    do
      echo "$* >>> # ${y} -+->>>:"
      ping -I ${LOCAL_IP} -f -c 10000 -W 1 -s 2048 ${y}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  elif [[ -f ${OTHER_IP} ]];then
    for i in $(cat ${OTHER_IP})
    do
      echo ">>> # ${i} -+->>>:"
      ping -f -c 10000 -W 1 -s 2048 ${i}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  fi
done
}
CHECK_NETWORK ${ADMIN_IP}
echo "==========="
CHECK_NETWORK ${PUBLIC_IP}
echo "==========="
CHECK_NETWORK ${PRIVATE_IP}
echo "==========="
CHECK_NETWORK ${GATEWAY_IP}



CHECK_NETWORK(){
for i in $(cat $1)
do
  LOCAL_IP=$(ip a|grep $i|awk '{print $2}'|sed 's/\/[0-9]*//g')
  if [[ -n ${LOCAL_IP} ]];then
    for y in $(cat $1)
    do
      echo "$* >>> # ${y} -+->>>:"
      ping -I ${LOCAL_IP} -f -c 10000 -W 1 -s 2048 ${y}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  elif [[ -f ${OTHER_IP} ]];then
    for i in $(cat ${OTHER_IP})
    do
      echo ">>> # ${i} -+->>>:"
      ping -f -c 10000 -W 1 -s 2048 ${i}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  fi
done
}
CHECK_NETWORK ${ADMIN_IP}
echo "==========="
CHECK_NETWORK ${PUBLIC_IP}
echo "==========="
CHECK_NETWORK ${PRIVATE_IP}
echo "==========="
CHECK_NETWORK ${GATEWAY_IP}

--------------------------

CHECK_NETWORK(){
RED_COLOUR="\033[1;5;42;37"
RES="\033[0m"
for i in $(cat $1)
do
  LOCAL_IP=$(ip a|grep $i|awk '{print $2}'|sed 's/\/[0-9]*//g')
  if [[ -n ${LOCAL_IP} ]];then
    for y in $(cat $1)
    do
      echo -n ">>> # ${y} -+->>>: "
      echo "$*"|awk -F '/' '{print $NF}'| tr "[:lower:]" "[:upper:]"
      ping -I ${LOCAL_IP} -f -c 10000 -W 1 -s 2048 ${y}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  elif [[ -f ${OTHER_IP} ]];then
    for i in $(cat ${OTHER_IP})
    do
      echo ">>> # ${i} -+->>>:"
      ping -f -c 10000 -W 1 -s 2048 ${i}|egrep --color=auto '*[0-9]%|min/avg/max/mdev = [0-9]*.*ms,'
    done
  fi
done
}
CHECK_NETWORK ${ADMIN_IP}
echo -e "===========\n"
CHECK_NETWORK ${PUBLIC_IP}
echo -e "===========\n"
CHECK_NETWORK ${PRIVATE_IP}
echo -e "===========\n"
CHECK_NETWORK ${GATEWAY_IP}
echo -e "\n"
