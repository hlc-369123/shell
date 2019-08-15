#!/bin/bash

check_init(){
if [ $? -ne 0 ];then
  echo "Please check "$1" $2 !"
  exit 1
fi
}

rpm -q initscripts >>/dev/null 2>&1
check_init initscripts package

read -e -p "Dst_IP_Addr : " ip_add
read -e -p "Dst_IP_Netmask : " ip_netmask
read -e -p "Dst_IP_Gateway : " ip_gateway
read -e -p "Dst_Network_Drive : " network_drive

ipcalc -4 -c ${ip_add}
check_init Dst_IP Addr
ipcalc -4 -c ${ip_gateway}
check_init Dst_IP Gateway

result=$(echo ${ip_netmask}|grep '\.')
if [[ "$result" != "" ]];then
  prefix=$(ipcalc -p ${ip_add} ${ip_netmask}|awk -F '=' '{print $2}')
  netmask=${ip_netmask}
elif [[ "$ip_netmask" -ge '0' && "$ip_netmask" -le '32' ]];then
  netmask=$(ipcalc -m ${ip_add}/${ip_netmask}|awk -F '=' '{print $2}')
  prefix=${ip_netmask}
else
  echo "请输入正确的掩码!..."
  exit 1
fi

echo -e "\n${ip_add}/${prefix} via ${ip_gateway} dev ${network_drive}\n"
read -e -p "Do you want to continue ? 【yes/other】" affirm

if [ "$affirm" == 'yes' ];then
  route add -net ${ip_add} netmask ${netmask} gw ${ip_gateway} dev ${network_drive}
  echo "${ip_add}/${prefix} via ${ip_gateway} dev ${network_drive}" >> /etc/sysconfig/network-scripts/route-${network_drive}
else
  echo "已经取消输入!..."
  exit 1
fi
