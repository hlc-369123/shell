#!/bin/bash

get_psql_info (){ 
docker exec -u postgres \
-it sds-postgres psql demon \
--pset=pager=off -c \
"select $1,$2,$3,$4,$5 from $6 where $7 = '$8';"; 
}

hostname=`hostname`
adminip=`get_psql_info name admin_ip status id \
up host name $hostname|grep 'active'|awk '{print $3}'`
masterip=`xms-manage db list|grep 'master db'|awk '{print $1}'`
if [[ $adminip != $masterip ]]; then
    echo "____________________请在IP为:$masterip主机上面进行查询！\
    _____________________"
    exit 1
fi

echo -e 'osd-id' '|  ' 'admin-ip' '  |  '\
  "\033[34m\033[4m系统_数据库盘符\033[0m" '  |                '\
  "\033[34m\033[4m系统_数据库wwn\033[0m" '                           |  '\
 '主机名'

osd_id=`get_psql_info disk_id name osd_id status \
up osd status active|grep 'active'|awk '{print $1}'`

for disk_id in $(echo $osd_id)
do
    eval $(get_psql_info id disk_id name osd_id status osd disk_id ${disk_id}|\
    grep 'active'|awk '{printf("osd_name=%s;osdid=%s;",$5,$7)}')
    eval $(get_psql_info host_id device wwid status id disk id $disk_id|\
    grep 'active'|awk '{printf("host_id=%s; disk_name=%s; wwn_id=%s;",$1,$3,$5)}')
    eval $(get_psql_info name admin_ip status id up host id $host_id|\
    grep 'active'|awk '{printf("host_name=%s; admin_ip=%s;",$1,$3)}')

    ssh -oStrictHostKeyChecking=no -oPasswordAuthentication=no \
    root@$host_name hostname > /dev/null 2>&1
    if [[ $? -ne '0' ]]; then
        echo "请添加到'$host_name'的免密登陆"
    fi

    sys_disk_name=`ssh $host_name lsblk|\
    grep -B 1 "/var/lib/ceph/osd/ceph-$osdid$"|grep disk|awk '{print $1}'`
    sys_wwn_id='wwn-'`ssh $host_name \
    lsblk -o NAME,MOUNTPOINT,TYPE,SIZE,ROTA,KNAME,PKNAME,VENDOR,MODEL,SERIAL,WWN -P -b|\
    grep disk|grep $sys_disk_name|awk -F 'WWN=' '{print $NF}'|awk -F '"' '{print $2}'`
    sys_disk="\033[31m\033[5mFales\033[0m"
    if [[ $sys_disk_name == $disk_name ]]; then
        sys_disk="\033[32mTrue\033[0m"
    fi
    sys_wwn="\033[31m\033[5mFales\033[0m"
    if [[ $sys_wwn_id == $wwn_id ]]; then
        sys_wwn="\033[32mTrue\033[0m"
    fi

    echo -e "$osd_name" ' |' "$admin_ip"  '| '\
      "\033[33m$sys_disk_name\033[0m"  '_' "\033[33m$disk_name\033[0m"'--->'"$sys_disk" ' | '\
      "\033[36m$sys_wwn_id\033[0m"  '_'  "\033[36m$wwn_id\033[0m"'--->'"$sys_wwn"'  |  '  "$host_name"
done
