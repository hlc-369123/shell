#!/usr/bin/env bash

LOG_INFO='/tmp/operations/result'
RED_COLOUR="\033[1;41;37m"
BOLD="\033[4;1m"
BAI="\033[1;40;37m"
RES="\033[0m"

get_name=$(hostname)
get_ip=$(hostname -i)
echo -e "         ${BOLD}###########${get_name} ${get_ip}#############${RES}"
echo -e "\n         ${BAI}>>> 交互分区状态:${RES}"
CHECK_SWAP=$(swapon -s|egrep '[a-z]|[0-9]')
if [[ -n ${CHECK_SWAP} ]];then
  echo -e "${RED_COLOUR}开启状态${RES}" |tee -a ${LOG_INFO}-warn.log
else
  echo "关闭状态"|tee -a ${LOG_INFO}.log
fi
echo -e "         ${BAI}>>> 负载:${RES}"
uptime|grep --color=never "average: [0-9]*.*"
sar -q|tail -n1|awk '{print "ldavg-1: "$4,"\tldavg-5: "$5,"\tldavg-15: "$6}'
echo -e "         ${BAI}>>> 根分区使用率和inode:${RES}"
df -h|head -n1&&df -h|grep "/$"
df -i|head -n1&&df -i|grep "/$"
echo -e "         ${BAI}>>> CPU和TOP10进程:${RES}"
top -bn 1|grep '^%Cpu'&&top -bn 1 -i -c|egrep -A 10 ^'.*PID'|awk '{$2=$3=$4=$5=$7=$8=$11="";print $0}'
echo -e "\n         ${BAI}>>> 防火墙状态:${RES}"
iptables_stat=$(systemctl is-active iptables)
firewalld_stat=$(systemctl is-active firewalld)
if [[ ${iptables_stat} == "active" || ${firewalld_stat} == "active" ]]; then
  echo -e "${RED_COLOUR}开启状态${RES}"&&iptables -nL --line-number|tee -a ${LOG_INFO}-warn.log
else
  echo "关闭状态"|tee -a ${LOG_INFO}.log
fi
echo -e "         ${BAI}>>> SELINUX 状态:${RES}"
if [[ $(getenforce) == 'Disabled' ]];then
 echo "关闭状态"|tee -a ${LOG_INFO}.log
else
   echo "${RED_COLOUR}开启状态${RES}"&&getenforce|tee -a ${LOG_INFO}-warn.log
fi
echo -e "         ${BAI}>>> 时间同步状态:${RES}"
time_sync_stat=$(timedatectl status|awk '/synchronized/ {print $3}')
if [[ ${time_sync_stat} == "yes" ]]; then
  echo "时间已同步"|tee -a ${LOG_INFO}.log
else
  echo -e "${RED_COLOUR}时间未同步${RES}"|tee -a ${LOG_INFO}-warn.log
fi
echo -e "         ${BAI}>>> 节点启动之后丢包情况:${RES}"
ifconfig |egrep -w 'inet|dropped'|awk '/inet/ {print $2} ; /dropped/ {print $1,$2,$3,$4,$5}'
echo -e "\n"
