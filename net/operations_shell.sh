#!/usr/bin/env bash

#定义文件位置
TEST_DB='/tmp/operations/db_list'
CLUSTER_IP='/tmp/operations/cluster_ip'
NETWORK_DIR='/tmp/operations/net/'
CHECK_DIR='/tmp/operations/check_dir/'
CK_IP='/tmp/operations/network_ck_ip'
ADMIN_IP='/tmp/operations/net/admin_ip'
PUBLIC_IP='/tmp/operations/net/public_ip'
PRIVATE_IP='/tmp/operations/net/private_ip'
GATEWAY_IP='/tmp/operations/net/gateway_ip'
OTHER_IP='/tmp/operations/net/other_ip'
LOG_INFO='/tmp/operations/result'
RED_COLOUR="\033[1;41;37m"
RES="\033[0m"
mkdir -p "${NETWORK_DIR}"

#检查时间是否同步的值,单位为毫秒.
CHECK_TIME_VALUE='500'
#OSD使用率告警检测值.
CHECK_OSD_USAGE='75'
#系统负载告警检测值.
SYS_LOAD="75"
#系统盘inode使用率告警检测值.
SYS_USE="65"
#系统cpu告警检测值.
CPU_USE="90"
#系统负载告警检测值.
MEMORY_USE="96"

#定义ssh端口号
ssh_port=22
SSH="ssh -o StrictHostKeyChecking=no -oPasswordAuthentication=no -o UserKnownHostsFile=/dev/null -p ${ssh_port}"
SCP="scp -r -oStrictHostKeyChecking=no -oPasswordAuthentication=no -P ${ssh_port}"

log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO]" "$@"
}

warn() {
  echo -e "${RED_COLOUR}$(date '+%Y-%m-%d %H:%M:%S') ${RES}""${RED_COLOUR}[WARN] ${RES}""${RED_COLOUR}$@${RES}"
}

#判断是否为管理节点（主要考虑管理节点对其他节点已经免密）
xms-manage db list 2>/dev/null | awk '{print $1}' 1>${TEST_DB}
for i in $(cat ${TEST_DB}); do
  ip a | grep $i &>/dev/null
  EXITVALUE=$?
  if [[ "$EXITVALUE" == '0' ]]; then
    break
  fi
done
if [[ "$EXITVALUE" != '0' ]]; then
  warn "Execute on the management node" && exit 1
fi

#接收访问数据库所需的方式
token_name=$*
if echo ${token_name} | egrep -w '\-\-token|\-t' &>/dev/null; then
  TOKEN=$(
    docker exec -it -u postgres sds-postgres psql demon --pset=pager=off \
      -c "select name,uuid from access_token;" | grep vasa-token | awk '{print $NF}' | tr -d "\r"
  )
elif [ "$#" == '0' ]; then
  read -p "Enter your UI_USER, please: " UI_USER
  read -p "Enter your UI_USER_PASSWRD, please: " UI_USER_PASSWRD
else
  echo "1) Check all node networks in the cluster."
  echo "2) Check all node resources in the cluster."
  echo "3) Customize a node to check the network and resources."
  echo "4) Clean up the files under \"/tmp/operations/\"."
  echo "5) exit."
  exit 0
fi
if [[ -n ${TOKEN} ]]; then
  CLI="-t ${TOKEN}"
  if ! xms-cli ${CLI} host list 1>/dev/null; then exit 1; fi
elif [[ -n ${UI_USER} && -n ${UI_USER_PASSWRD} ]]; then
  CLI="--user ${UI_USER} --password ${UI_USER_PASSWRD}"
  if ! xms-cli ${CLI} host list &>/dev/null; then warn "Incorrect username or password information..." && exit 1; fi
else
  warn "Value is empty..." && exit 1
fi

#获取集群各网段的ip
get_cluster_ips() {
  rm -f /tmp/operations/{*_ip,db_list,*.log,net/{*.log,*_ip}}&&touch "${CK_IP}"
  xms-cli $CLI -f '{{range .}}{{println .admin_ip .private_ip .public_ips .gateway_ips .type}}{{end}}' \
    host list |grep 'storage_server'| awk '{print $1","$2","$3","$4}' 1>${CLUSTER_IP}
  for i in $(grep ',' ${CLUSTER_IP}); do
    if [[ -n ${i} ]]; then
      if [[ $(echo $i | grep -o ',' | wc -l) == '3' ]]; then
        echo ${i} | sed -e 's/,/ /g' | awk '{print $1 >>"'${ADMIN_IP}'"} {print $2 >>"'${PRIVATE_IP}'"} {print $3 >>"'${PUBLIC_IP}'"} {print $4 >>"'${GATEWAY_IP}'"}'
      else
        for ip_list in $(echo ${i} | sed -e "s/,/ /g"); do echo $ip_list; done | sort -u 1>>${OTHER_IP}
      fi
    fi
  done
}

#网络检测
cat >/tmp/operations/net/check_network.sh <<\EOF
#!/usr/bin/env bash

CHECK_DIR='/tmp/operations/check_dir/'
ADMIN_IP="${CHECK_DIR}admin_ip"
PUBLIC_IP="${CHECK_DIR}public_ip"
PRIVATE_IP="${CHECK_DIR}private_ip"
GATEWAY_IP="${CHECK_DIR}gateway_ip"
OTHER_IP="${CHECK_DIR}other_ip"
LOG_INFO="${CHECK_DIR}result"

CHECK_NETWORK(){
  RED_COLOUR="\033[1;41;37m"
  RES="\033[0m"
  NET_FILE="$1"
  network_name=$(echo "$*"|awk -F '/' '{print $NF}'| tr "[:lower:]" "[:upper:]")

  for ip in $(cat "$NET_FILE")
  do
    ip a|grep $ip &>/dev/null
    EXITVALUE=$?
    if [[ $EXITVALUE == '0' ]];then
      LOCAL_IP=$(ip a|grep "$ip"|awk '{print $2}'|sed 's/\/[0-9]*//g')
      break
    fi
  done

  if [[ $EXITVALUE != '0' ]];then
    echo -e "${RED_COLOUR} ${network_name} ${RES} network address not found"|tee -a ${LOG_INFO}_warn.log&&return
  fi

  if [[ -n ${LOCAL_IP} ]];then
    for net_ip in $(cat "$NET_FILE")
    do
      if [[ ! -n "$net_ip" ]]; then
        continue
      elif [[ "${LOCAL_IP}" != "${net_ip}" ]]; then
        echo "                      >>>:SOU:${LOCAL_IP} DES:${net_ip} -+->>>: ${network_name}"
        ping -I ${LOCAL_IP} -c 10 -W 1 -i 0.01 ${net_ip}|tee -a $*.log|awk -v ip_test=${net_ip}  -F 'packet loss' '/packet loss/ \
        {printf ip_test" >>> " $(NF-1)"\n"}'|awk '{print $1,$2,$NF}'|tee -a $*_re.log|egrep --color=auto '[0-9]*%'
        num=$(cat $*_re.log|tail -n1|awk '{print $3}')
        if [[ -n ${num} && ${num} != '0%' ]];then
          echo -e "Please check network : ${RED_COLOUR}${network_name}   \"${LOCAL_IP} ---> ${net_ip}\" packet loss is \"${num}\"${RES}"|tee -a ${LOG_INFO}_warn.log
        fi
      fi
    done
  elif [[ -f ${OTHER_IP} && $* == ${OTHER_IP} ]];then
    for check_ip in $(cat ${OTHER_IP})
    do
      echo ">>> # ${check_ip} -+->>>:"
      ping -c 10 -W 1 -i 0.1 ${net_ip}|tee -a $*.log|awk -v ip_test=${net_ip}  -F 'packet loss' '/packet loss/ \
      {printf ip_test" >>> " $(NF-1)"\n"}'|awk '{print $1,$2,$NF}'|tee -a $*_re.log|egrep --color=auto '[0-9]*%'
      num=$(cat $*_re.log|tail -n1|awk '{print $3}')
      if [[ -n ${num} && ${num} != '0%' ]];then
        echo -e "Please check the : ${RED_COLOUR}\"${check_ip}\" packet loss is \"${num}\"${RES}"|tee -a ${LOG_INFO}_warn.log
      fi
    done
  fi
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

CHECK_DIR='/tmp/operations/check_dir/'
LOG_INFO="${CHECK_DIR}result"
RED_COLOUR="\033[1;41;37m"
RES="\033[0m"
SYS_LOAD="75"
SYS_USE="68"
CPU_USE="90"
MEMORY_USE="96"
get_name=$(hostname)
get_ip=$(hostname -i)

#Swap status
CHECK_SWAP=$(swapon -s|egrep '[a-z]|[0-9]')
if [[ -n ${CHECK_SWAP} ]];then
  echo -e "${RED_COLOUR}Swap is on ${RES}" |tee -a ${LOG_INFO}_warn.log
else
  echo "Swap is off">> ${LOG_INFO}.log
fi

#system load
uptime|grep --color=never "average: [0-9]*.*"|awk \
'$11>="'$SYS_LOAD'" || $12>="'$SYS_LOAD'" || $13>="'$SYS_LOAD'" {print $0 >> warn}' warn="${LOG_INFO}_warn.log"
sar -q|tail -n1|awk '{print "ldavg-1: "$4,"\tldavg-5: "$5,"\tldavg-15: "$6}'>> ${LOG_INFO}.log

#system disk use and disk inode
sys_use=$(df -h|head -n1&&df -h|grep "/$")
sys_inode=$(df -i|head -n1&&df -i|grep "/$")
df -h|grep "/$"|awk '{print $(NF-1)}'|sed 's/%//'|awk \
'$1>="'$SYS_USE'" {print sys_use >> warn}' sys_use="$sys_use" warn="${LOG_INFO}_warn.log"
df -i|grep "/$"|awk '{print $(NF-1)}'|sed 's/%//'|awk \
'$1>="'$SYS_USE'" {print sys_inode >> warn}' sys_inode="$sys_inode" warn="${LOG_INFO}_warn.log"

#system cpu use
cpu_top=$(top -bn 1|grep '^%Cpu'&&top -bn 1 -i -c|egrep -A 10 ^'.*PID'|awk '{$2=$3=$4=$5=$7=$8=$11="";print $0}')
top -n 1 |grep Cpu | cut -d "," -f 1,2|awk \
'$2>="'$CPU_USE'" || $4>="'$CPU_USE'" {print cpu_top >> warn}' cpu_top="$cpu_top" warn="${LOG_INFO}_warn.log"

#Memory
free -m | awk '/Mem:/ {print (1-$7/$2)*100}'|awk \
'$1>="'${MEMORY_USE}'" {print Memoy >> warn}' Memoy="$(free -h)" warn="${LOG_INFO}_warn.log"

#Firewalld
iptables_stat=$(systemctl is-active iptables)
firewalld_stat=$(systemctl is-active firewalld)
if [[ ${iptables_stat} == "active" || ${firewalld_stat} == "active" ]]; then
  echo -e "${RED_COLOUR}Firewall is on, please confirm that SDS required policy has been added${RES}"|tee -a ${LOG_INFO}_warn.log
else
  echo "Firewall is off"|tee -a ${LOG_INFO}.log >> ${LOG_INFO}.log
fi

#SELINUX
if [[ $(getenforce) == 'Disabled' ]];then
 echo "SELINUX is off" >> ${LOG_INFO}.log
else
   echo "${RED_COLOUR}SELINUX is on${RES}"&&getenforce|tee -a ${LOG_INFO}_warn.log
fi

#service
server_list='network docker xmsd xdc'
for server in ${server_list}
do
  systemctl is-active ${server}.service &>/dev/null
  if [[ $? -ne 0 ]]; then
    echo -e "${RED_COLOUR}${server}.service not active${RES}"|tee -a ${LOG_INFO}_warn.log
  fi
  sleep 0.1
done
echo ""
EOF

sed -i '2,12s/^SYS_LOAD=.*/SYS_LOAD="'${SYS_LOAD}'"/' /tmp/operations/net/check_resource.sh
sed -i '2,12s/^SYS_USE=.*/SYS_USE="'${SYS_USE}'"/' /tmp/operations/net/check_resource.sh
sed -i '2,12s/^CPU_USE=.*/CPU_USE="'${CPU_USE}'"/' /tmp/operations/net/check_resource.sh
sed -i '2,12s/^MEMORY_USE=.*/MEMORY_USE="'${MEMORY_USE}'"/' /tmp/operations/net/check_resource.sh

#结果判断
cat >/tmp/operations/net/get_result.sh <<\EOF
#!/usr/bin/env bash

CHECK_DIR='/tmp/operations/check_dir/result'
get_name=$(hostname)
get_ip=$(hostname -i)
get_result=$1
BOLD="\033[4;1m"
RED="\033[1;41;37m"
RES="\033[0m"

if [[ -f "${CHECK_DIR}_warn.log" ]];then
  echo -e "         ${BOLD}>>> ${get_name}_${get_ip} The warning or exception information is as follows:${RES}"
  while read -r line
  do
    echo -e "${RED} $line ${RES}"
  done < ${CHECK_DIR}_warn.log
  echo ""
fi
EOF

#检查ip合法性
Enter_ADMIN_IP() {
  read -p "Enter your ADMIN_NETWORK_IP, please: " ADMIN_NETWORK_IP
  local IP=${ADMIN_NETWORK_IP}
  VALID_CHECK=$(echo $IP | awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
  if echo $IP | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" &>/dev/null; then
    if [ ${VALID_CHECK:-no} == "yes" ]; then
      echo "${IP}" 1>${ADMIN_IP}
      distribution_of_ip ${ADMIN_IP} scp
      distribution_of_ip ${CK_IP} resource
      distribution_of_ip ${CK_IP} check_network
      distribution_of_ip ${CK_IP} clockdiff
    else
      warn "IP ${IP} not available!"&&exit 1
    fi
  else
    warn "IP format error!"&&exit 1
  fi
}

#时间差
time_sync_local() {
  local check_ip=$1
  clockdiff -o1 ${check_ip}
}

#检查ceph集群状态
ceph_status() {
  local ceph_stat=$(ceph health 2>/dev/null)
  if [[ "${ceph_stat}" != HEALTH_OK ]]; then
    echo -e "${RED_COLOUR} $(ceph health) ${RES}\n" |tee -a ${LOG_INFO}_cluster_warn.log
  fi
}

#获取osd使用率
osd_use() {
  ceph osd df 2>/dev/null | sort -n -k 7 | awk '{print $1,$7}' | grep "^[0-9]" | awk '{if ($2 >= '$CHECK_OSD_USAGE') print "The usage is greater than OSD of'$CHECK_OSD_USAGE'%:\t" "\033[1;41;37m""osd_ID: osd."$1"\tUSE: "$2"%""\033[0m\n"}' |tee -a ${LOG_INFO}_cluster_warn.log
}

#判断ssh
check_self_login() {
  local local_admin_ip=$1
  local local_action=$2

  if [[ "${local_action}" == 'check_ssh' ]]; then
    net_loss=$(ping -c 10 -W 1 -i 0.1 "${local_admin_ip}" | grep -o [0-9]*.% | sed 's/%//')
    if [[ "${net_loss}" -gt '50' ]]; then
      warn "Ssh failed，please check the network,"${local_admin_ip}" "${net_loss}"% packet loss."
      return 1
    else
      $SSH root@"${local_admin_ip}" hostname &>/dev/null
      return $?
    fi
  elif [[ "${local_action}" == 'create_dir' ]]; then
    $SSH root@"${local_admin_ip}" "rm -f /tmp/operations/check_dir/{*_ip,*.log,*.sh};mkdir -p ${CHECK_DIR}" 2>/dev/null
  fi
}

#执行相关的动作
distribution_of_ip() {
  local admin_ip=$1
  local action=$2

  if [[ -f "${admin_ip}" && -s "${admin_ip}" ]]; then
    for ch_ip in $(cat "${admin_ip}"); do
      if for test_ip in $(cat ${CLUSTER_IP}) ;do echo $test_ip|awk -F ',' '{print $1"\n"$2"\n"$3"\n"$4}';done|sort -u|grep "${ch_ip}"$ &>/dev/null; then
        check_self_login ${ch_ip} check_ssh
        local flag=$?
        if [[ ${flag} -eq '0' && ${action} == 'scp' ]]; then
          log "${ch_ip} Sync_NodeInfo..."
          check_self_login ${ch_ip} create_dir
          $SCP ${NETWORK_DIR}* root@${ch_ip}:${CHECK_DIR} &>/dev/null
          if [[ $? -eq 0 ]]; then
            echo ${ch_ip} >>${CK_IP}
          else
            warn "${ch_ip} scp ${NETWORK_DIR} Failed" | tee -a ${LOG_INFO}_warn.log
          fi
        elif [[ ${action} == 'check_network' ]]; then
          log "${ch_ip} CheckNetwork..."
          $SSH root@${ch_ip} "bash ${CHECK_DIR}check_network.sh &>/dev/null &" 2>/dev/null
        elif [[ ${action} == 'resource' ]]; then
          log "${ch_ip} CheckResource..."
          $SSH root@${ch_ip} "bash ${CHECK_DIR}check_resource.sh &>/dev/null &" 2>/dev/null
        elif [[ ${action} == 'get_result' ]]; then
          log "${ch_ip} GetResult..."
          $SSH root@${ch_ip} "bash ${CHECK_DIR}get_result.sh" 2>/dev/null |tee -a ${LOG_INFO}_cluster_warn.log
        elif [[ ${flag} -eq '0' && ${action} == 'clean_env' ]]; then
            log "${ch_ip} CleanCheckInfo..."
            $SSH root@${ch_ip} "rm -f /tmp/operations/{*_ip,db_list,*.log,check_dir/{*.log,*_ip,*.sh}}" 2>/dev/null
        elif [[ ${action} == 'clockdiff' ]]; then
          time_sync_stat=$($SSH root@${ch_ip} "timedatectl status|awk '/synchronized/'" 2>/dev/null | awk '{print $3}')
          if [[ ${time_sync_stat} == "yes" ]]; then
            echo "Time is synchronized" >>${LOG_INFO}.log
          else
            time_sync_local ${ch_ip} | tee | awk '{if ($NF >= '$CHECK_TIME_VALUE') print '$ch_ip' " The difference between the time and this node is " $NF"ms"}' >>${CHECK_DIR}result_warn.log
          fi
        fi
      else
        warn "This IP is not found in the cluster.";echo && exit 1
      fi
    done
  else
    warn "Not found on this node need \"${ADMIN_IP}\" file."
  fi
}

#功能调用
PS3="Select the sequence number of options to execute:=>"
num=1
select choice in Cluster_network Get_res Custom_IP Clean_env Quit; do
  case $choice in
  Cluster_network)
    get_cluster_ips
    distribution_of_ip ${ADMIN_IP} scp
    distribution_of_ip ${CK_IP} check_network
    wait
    log "Please later...\n" && sleep 5
    distribution_of_ip ${CK_IP} get_result
    break
    ;;
  Get_res)
    get_cluster_ips
    distribution_of_ip ${ADMIN_IP} scp
    distribution_of_ip ${CK_IP} resource
    wait
    distribution_of_ip ${CK_IP} clockdiff
    log "Please later...\n" && sleep 5
    distribution_of_ip ${CK_IP} get_result
    ceph_status
    osd_use
    break
    ;;
  Custom_IP)
    get_cluster_ips
    Enter_ADMIN_IP
    log "Please later...\n" && sleep 5
    distribution_of_ip ${CK_IP} get_result &>/dev/null
    ceph_status
    osd_use
    break
    ;;
  Clean_env)
    get_cluster_ips
    distribution_of_ip ${ADMIN_IP} clean_env
    rm -f /tmp/operations/{*_ip,db_list,*.log,net/{*.log,*_ip,*.sh}}
    break
    ;;
  Quit)
    exit 0
    ;;
  *)
    if [ -z "$choice" ]; then
      if [ "$num" -ge 3 ]; then
        warn "$num)You can rerun!..."
        exit 2
      else
        warn "$num)Please enter the correct serial number!"
      fi
      ((num++))
    fi
    ;;
  esac
done
