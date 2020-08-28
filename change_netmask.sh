#!/bin/bash
# 此脚本用于离线修改网络时修改网卡的配置文件

network_dev=$(grep '102.1.1' /etc/sysconfig/network-scripts/*|awk -F ":" '{print $1}')
net_dev_num=$(wc -l $network_dev|grep -v 'total'|wc -l)
ip -4 a|grep '102.1.1'
if [[ "${net_dev_num}" -eq 1 ]];then
  echo "${network_dev}"
  net_dev=$(echo ${network_dev}|awk -F 'ifcfg-' '{print $2}')
  if grep '^NETMASK=255.255.255.0' "${network_dev}";then
    cp "${network_dev}" "${network_dev}".bak
    sed -i 's/NETMASK=255.255.255.0/NETMASK=255.255.0.0/' "${network_dev}"
    ifdown ${net_dev} ; ifup ${net_dev}&&ip -4 a|grep '102.1.1'
  elif grep '^PREFIX=24' "${network_dev}";then
    cp "${network_dev}" "${network_dev}".bak
    sed -i 's/PREFIX=24/PREFIX=16/' "${network_dev}"
    ifdown ${net_dev} ; ifup ${net_dev}&&ip -4 a|grep '102.1.1'
  else
    echo "网卡${network_dev}不是24位掩码，需要确认后继续操作"
  fi
else
  echo -e "没有获取到网卡的配置文件，或者获取到的不为一个，请确认是否存在该网卡信息:\n\n${network_dev}\n"
fi

# 配合以下脚本使用
for i in `cat host_list`
do
  ssh $i bash /tmp/change_netmask.sh
  read -p "Please make sure ['y'/'other']:" sure
  if [[ "${sure}" != 'y' ]];then
    break
  fi
done
