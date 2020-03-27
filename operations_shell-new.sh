#!/usr/bin/env bash

TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
mkdir -p /tmp/operations/net
rm -f /tmp/operations/net/*

echo -e 'Judgment_for_management'
xms-manage db list|awk '{print $1}' 1>${TEST_DB}
for i in $(cat ${TEST_DB})
do
  if ip a|grep $i &>/dev/null;then
    break
  else
    echo 'Execute on the management node'&&exit 1
  fi
done

echo -e 'Generate_IP_list'
token_name=$*
if echo ${token_name}|egrep -w '\-\-token|\-t' &>/dev/null;then
  TOKEN=$(docker exec -it -u postgres sds-postgres psql demon --pset=pager=off -c "select name,uuid from access_token;"|grep vasa-token|awk '{print $NF}'|tr -d "\r")
else
  read -p "Enter your UI_USER, please: " UI_USER
  read -p "Enter your UI_USER_PASSWRD, please: " UI_USER_PASSWRD
fi
if [[ -n ${TOKEN} ]]; then
  CLI="-t ${TOKEN}"
elif [[ -n ${UI_USER}&&-n ${UI_USER_PASSWRD} ]]; then
  CLI="--user ${UI_USER} --password ${UI_USER_PASSWRD}"
  if ! xms-cli $CLI host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
else
 echo -e "Value is empty...!"&&exit 1
fi
PS3="请选择要执行得选项序列数字:=>"
num=1
select choice in Cluster_nodes Custom_IP Quit
do
  case $choice in
    Cluster_nodes)
      xms-cli $CLI host list|awk '{print $14","$12","$10","$16}'|grep ^'[0-9]' 1>${CLUSTER_IP}
      for i in $(grep ',' ${CLUSTER_IP})
      do
        if [[ -n ${i} ]];then
          if [[ $(echo $i |grep -o ','|wc -l) == '3' ]];then
            echo ${i}|sed -e 's/,/ /g'|awk '{print $1 >>"'${ADMIN_IP}'"} {print $2 >>"'${PUBLIC_IP}'"} {print $3 >>"'${PRIVATE_IP}'"} {print $4 >>"'${GATEWAY_IP}'"}'
          else
            #for ip_list in $(echo ${i}|sed -e "s/,/ /g");do echo $ip_list 1>>${OTHER_IP};done
            for ip_list in $(echo ${i}|sed -e "s/,/ /g");do echo $ip_list;done|sort -u 1>>${OTHER_IP}
          fi
        fi
      done
      break
      ;;
    Custom_IP)
      read -p "Enter your ADMIN_NETWORK_IP, please: " ADMIN_NETWORK_IP
      read -p "Enter your CHECK_NETWORK_IP, please: " CHECK_NETWORK_IP
      echo ${ADMIN_NETWORK_IP} 1>${ADMIN_IP}
      echo ${CHECK_NETWORK_IP} 1>${OTHER_IP}
      break
      ;;
    Quit)
      exit 0
      ;;
    *)
      if [ -z "$choice" ];then
        if [ "$num" -ge 3 ];then
          echo "$num)您可以重新运行!..."
          exit 2
        else
          echo "$num)请输入正确的序列号!"
        fi
        ((num++))
      fi
  esac
done
