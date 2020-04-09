#!/usr/bin/env bash

ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'

CHECK_NETWORK(){
RED_COLOUR="\033[1;41;37m"
GREY_COLOUR="\033[1;40;37m"
RES="\033[0m"
for i in $(cat $1)
do
  LOCAL_IP=$(ip a|grep $i|awk '{print $2}'|sed 's/\/[0-9]*//g')
  if [[ ! -n $i ]]; then
    continue
  elif [[ -n ${LOCAL_IP} ]];then
    for y in $(cat $1)
    do
      if [[ ! ${LOCAL_IP} == ${y} ]]; then
        echo -n "                      >>>:SOU:${LOCAL_IP} DES:${y} -+->>>: "
        echo "$*"|awk -F '/' '{print $NF}'| tr "[:lower:]" "[:upper:]"
        ping -I ${LOCAL_IP} -c 10 -W 1 -i 0.01 ${y}|tee -a $*.log|awk '/ping statistics/ {printf $2" >>> "} ; /.[0-9]%/ {print $6}'|tee -a $*_re.log|xargs -I {} echo -e "${GREY_COLOUR}{}${RES}"
        num=$(cat $*_re.log|tail -n1|awk '{print $3}')
        if [[ -n ${num} && ${num} != '0%' ]];then
          echo -e "Please check the : ${RED_COLOUR}\"${LOCAL_IP} ---> ${y}\" packet loss is \"${num}\"${RES}"
        fi
      fi
    done
  elif [[ -f ${OTHER_IP} && $* == ${OTHER_IP} ]];then
    for i in $(cat ${OTHER_IP})
    do
      echo ">>> # ${i} -+->>>:"
      ping -c 10 -W 1 -i 0.1 ${i}|tee -a $*.log|awk '/ping statistics/ {printf $2" >>> "} ; /.[0-9]%/ {print $6}'|tee -a $*_re.log|egrep --color=auto '[0-9]*%'
      num=$(cat $*_re.log|tail -n1|awk '{print $3}')
      if [[ -n ${num} && ${num} != '0%' ]];then
        echo -e "Please check the : ${RED_COLOUR}\"${i}\" packet loss is \"${num}\"${RES}"
      fi
    done
  fi
done
}

echo -e "\n==========="
for ip_file in ${ADMIN_IP} ${PUBLIC_IP} ${PRIVATE_IP} ${GATEWAY_IP} ${OTHER_IP}
do
  grep [0-9] ${ip_file} &> /dev/null
  if [[ $? -eq 0 && -f ${ip_file} ]]; then
    CHECK_NETWORK ${ip_file}
  fi
done
echo -e "\n"
