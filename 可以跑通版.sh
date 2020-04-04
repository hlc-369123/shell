#!/usr/bin/env bash

#定义文件位置
TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
NETWORK_DIR='/tmp/operations/net/'
NETWORK_CK_IP='/tmp/operations/network_ck_ip'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
LOG_INFO='/tmp/operations/result'
rm -rf /tmp/operations/*
mkdir -p /tmp/operations/net

#判断是否为管理节点（主要考虑管理节点对其他节点已经免密）
xms-manage db list|awk '{print $1}' 1>${TEST_DB}
for i in $(cat ${TEST_DB})
do
  if ip a|grep $i &>/dev/null;then
    break
  else
    echo 'Execute on the management node'&&exit 1
  fi
done

#接收访问数据库所需的方式
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

#获取集群各网段的ip
xms-cli $CLI host list|awk '{print $14","$12","$10","$16}'|grep ^'[0-9]' 1>${CLUSTER_IP}
for i in $(grep ',' ${CLUSTER_IP})
do
  if [[ -n ${i} ]];then
    if [[ $(echo $i |grep -o ','|wc -l) == '3' ]];then
      echo ${i}|sed -e 's/,/ /g'|awk '{print $1 >>"'${ADMIN_IP}'"} {print $2 >>"'${PUBLIC_IP}'"} {print $3 >>"'${PRIVATE_IP}'"} {print $4 >>"'${GATEWAY_IP}'"}'
    else
      for ip_list in $(echo ${i}|sed -e "s/,/ /g");do echo $ip_list;done|sort -u 1>>${OTHER_IP}
    fi
  fi
done

#网络检测
cat > /tmp/operations/net/check_network.sh << \EOF
#!/usr/bin/env bash

TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
NETWORK_DIR='/tmp/operations/net/'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'

CHECK_NETWORK(){
RED_COLOUR="\033[1;5;42;31m"
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
        ping -I ${LOCAL_IP} -c 10 -W 1 -i 0.1 ${y}|tee -a $*.log|awk '/ping statistics/ {printf $2" >>> "} ; /.[0-9]%/ {print $6}'|tee -a $*_re.log|egrep --color=auto '[0-9]*%'
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
EOF

cat > /tmp/operations/net/check_resource.sh << \EOF
#!/usr/bin/env bash

TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
NETWORK_DIR='/tmp/operations/net/'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'

get_name=$(hostname)
get_ip=$(hostname -i)
echo -e "\n########${get_name}"\c"${get_ip}"\c"#############\n"
CHECK_SWAP=$(swapon -s|egrep '[a-z]|[0-9]')
if [[ -n ${CHECK_SWAP} ]];then
  echo "Swap_Is_On" |tee -a ${LOG_INFO}-warn.log
else
  echo "Swap_Is_Off"|tee -a ${LOG_INFO}.log
fi

uptime|grep --color=auto "average: [0-9]*.*"
sar -q|tail -n1|awk '{print "ldavg-1: "$4,"\tldavg-5: "$5,"\tldavg-15: "$6}'

df -h|head -n1&&df -h|grep "/$"
df -i|head -n1&&df -i|grep "/$"

top -n 1|grep ^'%Cpu'&&top -bn 1 -i -c|egrep -A 10 ^'.*PID'|awk '{$2=$3=$4=$5=$7=$8=$11="";print $0}'

iptables_stat=$(systemctl is-active iptables)
firewalld_stat=$(systemctl is-active firewalld)
if [[ ${iptables_stat} == "active" || ${firewalld_stat} == "active" ]]; then
  echo "firewall-policyis_active"&&iptables -nL --line-number|tee -a ${LOG_INFO}-warn.log
else
  echo "firewall-policyis_disable"|tee -a ${LOG_INFO}.log
fi

if [[ $(getenforce) == 'Disabled' ]];then
 echo "Selinux_Is_Disable"|tee -a ${LOG_INFO}.log
else
 echo "Selinux_Is_Enable"&&getenforce|tee -a ${LOG_INFO}-warn.log
fi

time_sync_stat=$(timedatectl status|awk '/synchronized/ {print $3}')
if [[ ${time_sync_stat} == "yes" ]]; then
  echo "time_is_sync"|tee -a ${LOG_INFO}.log
else
  echo "time_not_sync"|tee -a ${LOG_INFO}-warn.log
fi
EOF

time_sync_local(){
  local check_ip=$1
  clockdiff -o1 ${check_ip}
}

osd_use(){
  ceph osd df|sort -n -k 7|awk '{print $1,$7}'|grep "^[0-9]"|awk '{print "osd_ID: osd."$1"\tUSE: "$2"%"}'
}

check_self_login() {
  local local_admin_ip=$1
  local local_action=$2
  local self_login="false"
  ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${local_admin_ip} hostname &> /dev/null
  if [[ $? -eq 0 && -z ${local_action} ]]; then
    self_login="true"
    echo ${self_login}
  elif [[ $? -eq 0 && -n ${local_action} ]]; then
    ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${local_admin_ip} "mkdir -p ${NETWORK_DIR}&&rm -f /tmp/operations/net/{admin_ip,public_ip,private_ip,gateway_ip,other_ip,*.log,*.sh}"
  fi
}

distribution_of_ip(){
  local admin_ip=$1
  local action=$2
for i in $(cat ${admin_ip})
do
  ip address |grep ${i} &> /dev/null
  if [[ $? -ne 0 ]]; then
    flag=$(check_self_login ${i})
    if [[ ${flag} == 'true' && ${action} == 'scp' ]];then
      check_self_login ${i} create_dir
      scp -r -oStrictHostKeyChecking=no -oPasswordAuthentication=no ${NETWORK_DIR}* root@${i}:${NETWORK_DIR} &> /dev/null
      if [[ $? -eq 0 ]]; then
        echo ${i} >> ${NETWORK_CK_IP}
      else
        echo "${i} scp ${NETWORK_DIR} Failed"|tee -a ${LOG_INFO}-warn.log
      fi
    elif [[ ${flag} == 'true' && ${action} == 'check_network' ]]; then
      ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "bash ${NETWORK_DIR}check_network.sh"
    elif [[ ${flag} == 'true' && ${action} == 'resource' ]]; then
       ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "bash ${NETWORK_DIR}check_resource.sh"
    elif [[ ${flag} == 'true' && ${action} == 'clockdiff' ]]; then
      echo -e "\n"
      time_sync_local ${i}
    fi
  elif [[ $? -eq 0 && ${action} == 'resource' ]]; then
    bash ${NETWORK_DIR}check_resource.sh
  fi
done
}

#执行检查方式
PS3="请选择要执行得选项序列数字:=>"
num=1
select choice in Cluster_nodes Custom_IP Quit
do
  case $choice in
    Cluster_nodes)
      distribution_of_ip ${ADMIN_IP} scp
      distribution_of_ip ${NETWORK_CK_IP} check_network
      bash ${NETWORK_DIR}check_network.sh
      distribution_of_ip ${ADMIN_IP} resource
      bash ${NETWORK_DIR}check_resource.sh
      distribution_of_ip ${ADMIN_IP} clockdiff
      echo -e "\n"
      osd_use
      break
      ;;
    Custom_IP)
      read -p "Enter your ADMIN_NETWORK_IP, please: " ADMIN_NETWORK_IP
      read -p "Enter your CHECK_NETWORK_IP, please: " CHECK_NETWORK_IP
      echo ${ADMIN_NETWORK_IP} 1>${ADMIN_IP}
      echo ${CHECK_NETWORK_IP} 1>${OTHER_IP}
      CHECK_NETWORK ${OTHER_IP}
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
