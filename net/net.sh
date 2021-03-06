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
BAI="\033[1;40;37m"
RES="\033[0m"
mkdir -p /tmp/operations/net
rm -f /tmp/operations/{*_ip,db_list,*.log,net/*}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO]" "$@"
}

warnlog() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')" "[WARN]" "$@"
}

#判断是否为管理节点（主要考虑管理节点对其他节点已经免密）
xms-manage db list 2>/dev/null | awk '{print $1}' 1>${TEST_DB}
for i in $(cat ${TEST_DB}); do
  ip a | grep $i &>/dev/null
  EXITVALUE=$?
  if [[ $EXITVALUE == '0' ]]; then
    break
  fi
done
if [[ $EXITVALUE != '0' ]]; then
  warnlog "Execute on the management node" && exit 1
fi

#接收访问数据库所需的方式
token_name=$*
if echo ${token_name} | egrep -w '\-\-token|\-t' &>/dev/null; then
  TOKEN=$(docker exec -it -u postgres sds-postgres psql demon --pset=pager=off -c "select name,uuid from access_token;" | grep vasa-token | awk '{print $NF}' | tr -d "\r")
else
  read -p "Enter your UI_USER, please: " UI_USER
  read -p "Enter your UI_USER_PASSWRD, please: " UI_USER_PASSWRD
fi
if [[ -n ${TOKEN} ]]; then
  CLI="-t ${TOKEN}"
  if ! xms-cli $CLI host list 1>/dev/null; then exit 1; fi
elif [[ -n ${UI_USER} && -n ${UI_USER_PASSWRD} ]]; then
  CLI="--user ${UI_USER} --password ${UI_USER_PASSWRD}"
  if ! xms-cli $CLI host list &>/dev/null; then warnlog "Wrong information..." && exit 1; fi
else
  warnlog "Value is empty...!" && exit 1
fi

#获取集群各网段的ip
xms-cli $CLI host list|grep "storage_server"|awk '{print $14","$12","$10","$16}'|grep ^'[0-9]' 1>${CLUSTER_IP}
for i in $(grep ',' ${CLUSTER_IP}); do
  if [[ -n ${i} ]]; then
    if [[ $(echo $i | grep -o ',' | wc -l) == '3' ]]; then
      echo ${i} | sed -e 's/,/ /g' | awk '{print $1 >>"'${ADMIN_IP}'"} {print $2 >>"'${PUBLIC_IP}'"} {print $3 >>"'${PRIVATE_IP}'"} {print $4 >>"'${GATEWAY_IP}'"}'
    else
      for ip_list in $(echo ${i} | sed -e "s/,/ /g"); do echo $ip_list; done | sort -u 1>>${OTHER_IP}
    fi
  fi
done

#网络检测
cat >/tmp/operations/net/check_network.sh <<\EOF
#!/usr/bin/env bash
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
LOG_INFO='/tmp/operations/result'
CHECK_NETWORK(){
RED_COLOUR="\033[1;41;37m"
GREY_COLOUR="\033[1;40;37m"
RES="\033[0m"
network_name=$(echo "$*"|awk -F '/' '{print $NF}')
for i in $(cat $1)
do
  ip a|grep $i &>/dev/null
  EXITVALUE=$?
  if [[ $EXITVALUE == '0' ]];then
    break
  fi
done
if [[ $EXITVALUE != '0' ]];then
  echo -e "${RED_COLOUR} ${network_name} ${RES} network not found"|tee -a ${LOG_INFO}_warn.log
  echo 'Execute on the management node'&&break
fi
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
          echo -e "Please check the : ${RED_COLOUR}\"${LOCAL_IP} ---> ${y}\" packet loss is \"${num}\"${RES}"|tee -a ${LOG_INFO}_warn.log
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
        echo -e "Please check the : ${RED_COLOUR}\"${i}\" packet loss is \"${num}\"${RES}"|tee -a ${LOG_INFO}_warn.log
      fi
    done
  fi
done
}
echo -e "\n==========="
#for ip_file in ${ADMIN_IP} ${PUBLIC_IP} ${PRIVATE_IP} ${GATEWAY_IP} ${OTHER_IP}
for ip_file in ${ADMIN_IP} ${PUBLIC_IP} ${PRIVATE_IP}
do
  grep [0-9] ${ip_file} &> /dev/null
  if [[ $? -eq 0 && -f ${ip_file} ]]; then
    CHECK_NETWORK ${ip_file}
  fi
done
echo -e "\n"
EOF

#资源信息
cat >/tmp/operations/net/check_resource.sh <<\EOF
#!/usr/bin/env bash
LOG_INFO='/tmp/operations/result'
RED_COLOUR="\033[1;41;37m"
BOLD="\033[4;1m"
BAI="\033[1;40;37m"
RES="\033[0m"
get_name=$(hostname)
get_ip=$(hostname -i)
echo -e "         ${BOLD}###########${get_name} ${get_ip}#############${RES}"
echo -e "\n         ${BAI}>>> 交互分区状态(Swap):${RES}"
CHECK_SWAP=$(swapon -s|egrep '[a-z]|[0-9]')
if [[ -n ${CHECK_SWAP} ]];then
  echo -e "${RED_COLOUR}Swap开启状态${RES}" |tee -a ${LOG_INFO}_warn.log
else
  echo "Swap关闭状态"|tee -a ${LOG_INFO}.log
fi
echo -e "         ${BAI}>>> 负载:${RES}"|tee -a ${LOG_INFO}.log
uptime|grep --color=never "average: [0-9]*.*"|tee -a ${LOG_INFO}.log
sar -q|tail -n1|awk '{print "ldavg-1: "$4,"\tldavg-5: "$5,"\tldavg-15: "$6}'|tee -a ${LOG_INFO}.log
echo -e "         ${BAI}>>> 根分区使用率和inode:${RES}"|tee -a ${LOG_INFO}.log
df -h|head -n1&&df -h|grep "/$"|tee -a ${LOG_INFO}.log|tee -a ${LOG_INFO}.log
df -i|head -n1&&df -i|grep "/$"|tee -a ${LOG_INFO}.log|tee -a ${LOG_INFO}.log
echo -e "         ${BAI}>>> CPU和TOP10进程:${RES}"|tee -a ${LOG_INFO}.log
top -bn 1|grep '^%Cpu'&&top -bn 1 -i -c|egrep -A 10 ^'.*PID'|awk '{$2=$3=$4=$5=$7=$8=$11="";print $0}'|tee -a ${LOG_INFO}.log
echo -e "\n         ${BAI}>>> 防火墙状态:${RES}"
iptables_stat=$(systemctl is-active iptables)
firewalld_stat=$(systemctl is-active firewalld)
if [[ ${iptables_stat} == "active" || ${firewalld_stat} == "active" ]]; then
  echo -e "${RED_COLOUR}防火墙为开启状态，请确认已添加sds所需策略${RES}"|tee -a ${LOG_INFO}_warn.log
else
  echo "防火墙关闭状态"|tee -a ${LOG_INFO}.log|tee -a ${LOG_INFO}.log
fi
echo -e "         ${BAI}>>> SELINUX 状态:${RES}"
if [[ $(getenforce) == 'Disabled' ]];then
 echo "SELINUX关闭状态"|tee -a ${LOG_INFO}.log
else
   echo "${RED_COLOUR}SELINUX开启状态${RES}"&&getenforce|tee -a ${LOG_INFO}_warn.log
fi
server_list='network docker xmsd xdc'
for server in ${server_list}
do
  systemctl is-active ${server}.service &>/dev/null
  if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOUR}${server}.service not active${RES}"|tee -a ${LOG_INFO}_warn.log
  fi
  sleep 0.1
done
echo -e "\n"
EOF

#结果判断
cat >/tmp/operations/net/get_result.sh <<\EOF
#!/bin/bash
LOG_INFO='/tmp/operations/result'
get_result=$1
BOLD="\033[4;1m"
RED="\033[1;40;31m"
RES="\033[0m"
if [[ ${get_result} == info ]];then
  LOG_INFO="${LOG_INFO}.log"
else
  LOG_INFO="${LOG_INFO}_warn.log"
fi
IFS=$'\n\n'
get_name=$(hostname)
get_ip=$(hostname -i)
if [[ -f ${LOG_INFO} && -s "${LOG_INFO}" ]];then
  echo -e "         ${BOLD}>>>${get_name}_${get_ip}告警或异常信息如下:${RES}"
  for i in $(cat ${LOG_INFO})
  do
    echo -e "${RED} ${i} ${RES}"
  done
  echo ""
#else
#  echo -e "         ${BOLD}>>>${get_name}_${get_ip}无告警${RES}"
fi
EOF

#时间差
time_sync_local() {
  local check_ip=$1
  clockdiff -o1 ${check_ip}
}

#获取osd使用率
osd_use() {
  #ceph osd df|sort -n -k 7|awk '{print $1,$7}'|grep "^[0-9]"|awk '{if ($2 > 80) print "\033[1;40;31m""osd_ID: osd."$1"\tUSE: "$2"%""\033[0m" ; else print "osd_ID: osd."$1"\tUSE: "$2"%"}'|tee -a ${LOG_INFO}.log
  ceph osd df | sort -n -k 7 | awk '{print $1,$7}' | grep "^[0-9]" | awk '{if ($2 >= 75) print "使用率大于75%的osd:\t" "\033[1;40;31m""osd_ID: osd."$1"\tUSE: "$2"%""\033[0m"}' | tee -a ${LOG_INFO}_warn.log
}

#判断ssh
check_self_login() {
  local local_admin_ip=$1
  local local_action=$2
  local self_login="false"
  ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${local_admin_ip} hostname &>/dev/null
  if [[ $? -eq 0 && -z ${local_action} ]]; then
    self_login="true"
    echo ${self_login}
  elif [[ -n ${local_action} ]] && ! ip addr | grep ${local_admin_ip} &>/dev/null; then
    ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${local_admin_ip} "rm -f /tmp/operations/{*_ip,db_list,*.log,net/*};mkdir -p ${NETWORK_DIR}"
  fi
}

#执行相关的动作
distribution_of_ip() {
  local admin_ip=$1
  local action=$2
  local origin=$3
  for i in $(cat ${admin_ip}); do
    if [[ $origin != 'Custom_IP' ]]; then
      ip address | grep ${i} &>/dev/null
      EXITVALUE=$?
    fi
    if [[ $EXITVALUE -ne 0 || $origin == 'Custom_IP' ]]; then
      flag=$(check_self_login ${i})
      if [[ ${flag} == 'true' && ${action} == 'scp' ]]; then
        log "${i} Sync_NodeInfo..."
        check_self_login ${i} create_dir
        scp -r -oStrictHostKeyChecking=no -oPasswordAuthentication=no ${NETWORK_DIR}* root@${i}:${NETWORK_DIR} &>/dev/null
        if [[ $? -eq 0 ]]; then
          echo ${i} >>${NETWORK_CK_IP}
        else
          warnlog "${i} scp ${NETWORK_DIR} Failed" | tee -a ${LOG_INFO}_warn.log
        fi
      elif [[ ${flag} == 'true' && ${action} == 'check_network' ]]; then
        log "${i} CheckNetwork..."
        ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "bash ${NETWORK_DIR}check_network.sh &>/dev/null &"
      elif [[ ${flag} == 'true' && ${action} == 'resource' ]]; then
        log "${i} CheckResource..."
        ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "bash ${NETWORK_DIR}check_resource.sh &>/dev/null &"
      elif [[ ${flag} == 'true' && ${action} == 'get_result' ]]; then
        log "${i} GetResult..."
        ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "bash ${NETWORK_DIR}get_result.sh"
      elif [[ ${flag} == 'true' && ${action} == 'clean_env' ]]; then
        log "${i} CleanCheckInfo..."
        ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "rm -f /tmp/operations/{*_ip,db_list,*.log,net/*}"
      elif [[ ${flag} == 'true' && ${action} == 'clockdiff' ]]; then
        time_sync_stat=$(ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no root@${i} "timedatectl status|awk '/synchronized/'" | awk '{print $3}')
        if [[ ${time_sync_stat} == "yes" ]]; then
          echo "时间已同步" | tee -a ${LOG_INFO}.log
        else
          time_sync_local ${i} | tee | awk '{if ($NF >= 500) print '$i' " 时间和本节点差为 " $NF"ms"}' >>${LOG_INFO}_warn.log
        fi
      fi
    fi
  done
}

#功能调用
PS3="请选择要执行得选项序列数字:=>"
num=1
echo -e "1).检查网络;\n2).检查资源;\n3).自定义节点检查网络和资源;\n4).清理检查后文件;\n5).退出;\n"
select choice in Cluster_network Get_res Custom_IP Clean_env Quit; do
  case $choice in
  Cluster_network)
    distribution_of_ip ${ADMIN_IP} scp Cluster_network
    distribution_of_ip ${NETWORK_CK_IP} check_network Cluster_network
    log "$(hostname -i) CheckNetwork..."
    bash ${NETWORK_DIR}check_network.sh &>/dev/null
    wait
    #distribution_of_ip ${ADMIN_IP} resource Cluster_network
    #bash ${NETWORK_DIR}check_resource.sh
    #distribution_of_ip ${ADMIN_IP} clockdiff Cluster_network
    #echo -e "############\n         ${BAI}>>> OSD使用率:${RES}"
    #osd_use
    echo ""
    distribution_of_ip ${ADMIN_IP} get_result Cluster_network
    log "$(hostname -i) GetResult..."
    bash ${NETWORK_DIR}get_result.sh
    break
    ;;
  Get_res)
    distribution_of_ip ${ADMIN_IP} scp Get_res
    #distribution_of_ip ${NETWORK_CK_IP} check_network Get_res
    #bash ${NETWORK_DIR}check_network.sh
    distribution_of_ip ${ADMIN_IP} resource Get_res
    log "$(hostname -i) CheckResource..."
    bash ${NETWORK_DIR}check_resource.sh &>/dev/null
    wait
    distribution_of_ip ${ADMIN_IP} clockdiff Get_res
    #echo -e "############\n         ${BAI}>>> OSD使用率:${RES}"
    osd_use
    echo ""
    distribution_of_ip ${ADMIN_IP} get_result Get_res
    log "$(hostname -i) GetResult..."
    bash ${NETWORK_DIR}get_result.sh
    break
    ;;
  Custom_IP)
    read -p "Enter your ADMIN_NETWORK_IP, please: " ADMIN_NETWORK_IP
    echo ${ADMIN_NETWORK_IP} 1>${ADMIN_IP}
    distribution_of_ip ${ADMIN_IP} scp Custom_IP
    distribution_of_ip ${NETWORK_CK_IP} check_network Custom_IP
    distribution_of_ip ${ADMIN_IP} resource Custom_IP
    distribution_of_ip ${ADMIN_IP} clockdiff Custom_IP
    #echo -e "############\n         ${BAI}>>> OSD使用率:${RES}"
    osd_use
    echo ""
    distribution_of_ip ${ADMIN_IP} get_result Get_res
    break
    ;;
  Clean_env)
    distribution_of_ip ${ADMIN_IP} clean_env Clean_env
    log "$(hostname -i) CleanCheckInfo..."
    rm -f /tmp/operations/{*_ip,db_list,*.log,net/*}
    break
    ;;
  Quit)
    exit 0
    ;;
  *)
    if [ -z "$choice" ]; then
      if [ "$num" -ge 3 ]; then
        echo "$num)您可以重新运行!..."
        exit 2
      else
        echo "$num)请输入正确的序列号!"
      fi
      ((num++))
    fi
    ;;
  esac
done
