#!/bin/bash

jsdge(){
for i in {1..3}
do
    echo -e "请输入设备或者文件名称：\c"
    read file
    if [  ${file} != '' ];then break;fi
done
if [ $(df -h|grep ${file}|wc -l) -ne 1 ];then
    if [ $(lsblk|grep disk|grep -o ${file}|wc -l) -ne 1 ];then
        echo "请填写完整的设备名称！"&&exit 1
    fi
elif [ $(df -h|grep ${file}|wc -l) -eq 1 ];then
    break
else
    echo "请填写完整的文件名称！"&&exit 1
fi
}
jsdge 2>/dev/null
file_name=$(df -h|grep ${file}|awk '{print $NF}')
disk_name=$(lsblk|grep disk|grep -o ${file})
result=$(echo ${file_name} | grep "${file}")
disk_type=$(lsblk -o NAME,FSTYPE|grep ${disk_name}|awk '{print $2}')
if [[ "$result" != "" ]];then
    if [ -e ${file_name} ];then
        if [ $(ls ${file_name}|wc -l) == 0 ];then
            echo "这个是一个空目录！"
        fi
    fi
else
    if [ -b "/dev/${disk_name}" ];then
        if [ -z ${disk_type} ];then
            echo "未格式化"
        else
            echo "磁盘格式为${disk_type}"
        fi
    fi
fi

--------------------------------------------------------------------------------------------

#!/bin/bash

jsdge(){
for i in {1..3}
do
    echo -e "请输入设备或者文件名称：\c"
    read file
    if [  ${file} != '' ];then break;fi
done
if [ $(df -h|grep ${file}|wc -l) -ne 1 ];then
    if [ $(lsblk|grep disk|grep -o ${file}|wc -l) -ne 1 ];then
        echo "请填写完整的设备名称！"&&exit 1
    fi
elif [ $(df -h|grep ${file}|wc -l) -eq 1 ];then
    break
else
    echo "请填写完整的文件名称！"&&exit 1
fi
}

fio(){
fio --filename=$1 --direct=1 --rw=$2 --numjobs=$3 --iodepth=$4 \
--ioengine=libaio --bs=${5}k --group_reporting --name=$6 --log_avg_msec=500 \
--write_bw_log=test-fio --write_lat_log=test-fio --write_iops_log=test-fio --size=$7 --runtime=$8 --time_based
}

#disk_nam=$1 (固定值)
#rw_mode=$2 （固定值）
#numjobs=$3 （CPU逻辑核心数）
#iodepth=$4 （固定值）
#bs_num=$5 （变动值）
#fio_test_name=$6 （变动值）
#fio_test_size=$7 （不确定值）
#fio_test_runtime=$8 （300-500）

numjobs=$(cat /proc/cpuinfo |grep "processor"|wc -l)

file_name=$(df -h|grep ${file}|awk '{print $NF}')
disk_name=$(lsblk|grep disk|grep -o ${file})
result=$(echo ${file_name} | grep "${file}")
disk_type=$(lsblk -o NAME,FSTYPE|grep ${disk_name}|awk '{print $2}')

jsdge 2>/dev/null

if [[ "$result" != "" ]];then
    if [ -e ${file_name} ];then
        if [ $(ls ${file_name}|wc -l) == 0 ];then
            echo "这个是一个空目录！"
        fi
    fi
else
    if [ -b "/dev/${disk_name}" ];then
        if [ -z ${disk_type} ];then
            echo "未格式化"
        else
            echo "磁盘格式为${disk_type}"
        fi
    fi
fi


for i in
