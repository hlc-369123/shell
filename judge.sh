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
