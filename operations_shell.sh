#!/usr/bin/env bash

mkdir -p /tmp/operations
CHECK_NODE='check_node_list'
CHECK_IP='check_ip_list'
TEST_DB='db_list'
echo -e 'Judgment_for_management'
xms-manage db list|awk '{print $1}' 1>/tmp/operations/${TEST_DB}
for i in $(cat /tmp/operations/${TEST_DB})
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
      xms-cli $CLI host list|awk '{print $14","$12","$10","$16}'|grep ^[0-9] 1>/tmp/operations/${TEST_DB}
      cat /tmp/operations/${TEST_DB}|awk -F ',' '{print $1}' 1>/tmp/operations/${CHECK_NODE}
      rm -f /tmp/operations/${CHECK_IP}
      for test_list in $(cat /tmp/operations/${TEST_DB})
      do
        for the_one in $(echo $test_list|sed 's/,/ /g');do echo $the_one;done|sort -u 1>>/tmp/operations/${CHECK_IP}
      done
      break
      ;;
    Custom_IP)
      read -p "Enter your ADMIN_IP, please: " ADMIN_IP
      read -p "Enter your CHECK_NETWORK_IP, please: " CHECK_NETWORK_IP
      echo ${ADMIN_IP} 1>/tmp/operations/${CHECK_NODE}
      echo ${CHECK_NETWORK_IP} 1>/tmp/operations/${CHECK_IP}
      exit 0
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
