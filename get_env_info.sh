#!/bin/bash
LANG=UTF-8
HOST=`hostname`
#SERVER=`dmidecode |grep Product |head -n1|awk -F ':' '{print $2}'`
SERVER=`dmidecode | grep "System Information" -A9 | egrep "Manufacturer|Product|Serial"`
CPU=`cat /proc/cpuinfo |grep "model name"|head -n 1|awk -F ':' '{print $2}'`
SYSVER=`cat /etc/redhat-release`
KERNEL=`uname -a |awk '{print $3}'`
BIOS=`dmidecode -t bios|grep  Version`
MEM=`free -m|grep Mem|awk '{print $2}'`
RAIDMODEL=`/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -aALL|grep  "Product Name"|awk -F ':' '{print $2}'`
RAIDFW=`/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -aALL|grep  "FW Package Build"|awk -F ':' '{print $2}'`
RAIDCMOS=`lspci |grep MegaRAID|awk '{print $5,$11,$12}'`
#NETMODEL=`lspci | grep -i ethernet|awk -F ':' '{print $3$4 }'|sort -u|sed  s/^/"      "/g`
NETMODEL=`lspci | egrep -i 'ethernet|Technologies'|awk -F ':' '{print $3$4 }'|sed  s/^/"      "/g`
FIBRE=`cat /sys/class/fc_host/host*/symbolic_name|head -n1|sed  s/^/"       "/g`
NETVER=`ls /sys/class/net/ |egrep -v 'docker|vir|lo|br'`
DISK=`lsscsi|awk '{print $4$5}'|sort|uniq|sed  s/^/"       "/g`
DISKINFO=`lsscsi|awk '{print $NF}'`
#NVMeNAME=`nvme list |sed -n '3,$p'|awk -F '  +' '{print $3}'`
#NVMeSIZE=`nvme list |sed -n '3,$p'|awk -F '   +' '{print $6}'`
NVMEINFO=`nvme list |sed -n '3,$p'`
MEMORY=`dmidecode -t memory |egrep -i 'Manufacturer:|Type:|speed:'|sort -u`
echo "####################################################################"
echo "系统信息"
echo "Date Time:`date`"
echo "Server Model:"$SERVER
echo "HOSTNAME : "$HOST
echo "SYS VER  : "$SYSVER
echo "KERNEL   : "$KERNEL
echo "CPU INFO :"$CPU
echo "MEM TATOL: "$MEM"M"
echo "BIOS INFO:"$BIOS
echo "MEMORY INFO:"$MEMORY
echo "####################################################################"
echo "RAID卡信息"
echo "RAIDDEVICE:"$RAIDMODEL
echo "RAID   FW :"$RAIDFW
echo "RAID  CMOS:" $RAIDCMOS
echo "####################################################################"
echo "网卡信息"
echo -e "NET MODEL:" "\n$NETMODEL"
echo -e "FC DEVICE:" "\n$FIBRE"
lspci |grep -i Technologies
echo -e "网卡固件和驱动版本"
for i in $NETVER
        do
                echo "----------------------------------------------"
                echo $i
                ethtool -i $i|grep -E "driver|version|firmware-version"
        done
echo "####################################################################"
echo "硬盘信息"
#echo -e "DISK MODLE:" "\n$DISK"
for i in $DISKINFO
        do
        if [[ $i = /dev* ]]; then
           echo $i":"
           smartctl -a $i|grep -E "Model Family|Vendor|Device Model|Product|Rotation Rate"
        fi
        done

lsblk |grep disk
echo -e "********NVMe接口SSD*********"
echo -e "NVME INFO:"$NVMEINFO
