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
--------------------------------------------------------------------------------------------------------------------------------

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

run_fio(){
fio --filename=/dev/$1 --direct=1 --rw=$2 --numjobs=$3 --iodepth=$4 \
--ioengine=libaio --bs=${5}k --group_reporting --name=lc"$((fio_test_name++))" --log_avg_msec=500 \
--write_bw_log=test-fio --write_lat_log=test-fio --write_iops_log=test-fio --size=30G --runtime=10 --time_based
}

#disk_nam=$1 (固定值)
#rw_mode=$2 （固定值）
#numjobs=$3 （CPU逻辑核心数）
#iodepth=$4 （固定值）
#bs_num=$5 （变动值）
#fio_test_name=lc$((fio_test_name++)) （变动值）
#fio_test_size=30 （默认值30G）(计算公式：{缓存盘分区大小*0.6（写cache）*0.75（刷盘水位）*osd数量/副本数})
#fio_test_runtime=300 （300秒）(time_based,即使完全写入或者读取，也可以运行runtime指定的时间)
#blok_size=$(lsblk -o SIZE /dev/sdl|grep -v SIZE) (块的大小)

jsdge 2>/dev/null
numjobs=$(cat /proc/cpuinfo |grep "processor"|wc -l)
rw_mode="randwrite randread write read"
fio_test_name=1

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

for rw_mode in ${rw_mode}
do
    for bs_num in {1,4,1024,4096}
    do
        for iodepth in {4,32,64,128}
        do
            fio_file=${rw_mode}${bs_num}file$((fio_test_name++))
            mkdir /mnt/${fio_file}&&cd /mnt/${fio_file}&&dir
            run_fio ${disk_name} ${rw_mode} ${numjobs} ${iodepth} ${bs_num} > ./${fio_file}.txt
            sleep 5
        done
    done
done
------------------------------------------------------------------------------
#!/BIN/BASh

PS3="请选择磁盘:"
asd=$(lsblk|grep disk|awk '{printf $1" "}')
select choice in $asd Quit ;do
    case $choice in
        $choice)
            if [ "${choice}" == "Quit" ];then break;fi
            echo "disk is ${choice} "
            ;;
        *)
            echo "Enter error!"
            exit 2
    esac
done
----------------------------------------------------------------------------------
#!/bin/bash

disk_num=0
for i in $(lsblk |grep disk|awk '{print $1}')
do
    disk_type=$(lsblk -o NAME,FSTYPE|grep $i|awk '{print $2}')
    disk_info=$(lsblk -o NAME,SIZE|grep $i)
    if [  "${disk_type}" == '' ];then
        ((disk_num++))
        disk_type='未格式化'
        echo "$disk_info" |awk '{print $1"\t""'${disk_type}'""\t"$2}'
    fi
done
for ((i=1; i<=${disk_num}; i++))
do
    case ${i} in
        ${i})
            echo "不及格${i}！"
            ;;
    esac
done
---------------------------------------------------------------------------------

#!/bIN/BASH

run_fio(){
echo fio --filename=/dev/$1 --direct=1 --rw=$2 --numjobs=$3 --iodepth=$4 \
--ioengine=libaio --bs=${5}k --group_reporting --name=lc"$((fio_test_name++))" --log_avg_msec=500 \
--write_bw_log=test-fio --write_lat_log=test-fio --write_iops_log=test-fio --size=30G --runtime=10 --time_based
}

#disk_nam=$1 (固定值)
#rw_mode=$2 （固定值）
#numjobs=$3 （CPU逻辑核心数）
#iodepth=$4 （固定值）
#bs_num=$5 （变动值）
#fio_test_name=lc$((fio_test_name++)) （变动值）
#fio_test_size=30 （默认值30G）(计算公式：{缓存盘分区大小*0.6（写cache）*0.75（刷盘水位）*osd数量/副本数})
#fio_test_runtime=300 （300秒）(time_based,即使完全写入或者读取，也可以运行runtime指定的时间)
#blok_size=$(lsblk -o SIZE /dev/sdl|grep -v SIZE) (块的大小)

disk_name=''
for i in $(lsblk |grep disk|awk '{print $1}')
do
    disk_type=$(lsblk -o NAME,FSTYPE|grep $i|awk '{print $2}')
    disk_info=$(lsblk -o NAME,SIZE|grep $i)
    if [  "${disk_type}" == '' ];then
        disk_type='未格式化'
        disk_name="$disk_name $(echo "$disk_info" |awk '{print $1}')"
    fi
done
PS3="请选择磁盘序列数字:"
#disk_name=$(lsblk|grep disk|awk '{printf $1" "}')
if [ -z "$disk_name" ];then echo '系统上没有可测试的磁盘!...';exit 0;fi
num=1
select choice in $disk_name Quit
do
    case $choice in
        $choice)
            if [ "$choice" == "Quit" ];then
                exit 0
            elif [ -n "$choice" ];then
                disk_name="$choice"
                break
            elif [ -z "$choice" ];then
                if [ "$num" -ge 3 ];then
                    echo "$num)您可以重新运行!..."
                    exit 1
                else
                    echo "$num)请输入正确的序列号!"
                fi
                ((num++))
            fi
    esac
done

numjobs=$(cat /proc/cpuinfo |grep "processor"|wc -l)
rw_mode="randwrite randread write read"
fio_test_name=1
for rw_mode in ${rw_mode}
do
    for bs_num in {1,4,1024,4096}
    do
        for iodepth in {4,32,64,128}
        do
            #fio_file=${rw_mode}${bs_num}file$((fio_test_name++))
            #mkdir /mnt/${fio_file}&&cd /mnt/${fio_file}&&dir
            #run_fio ${disk_name} ${rw_mode} ${numjobs} ${iodepth} ${bs_num} > ./${fio_file}.txt
            run_fio ${disk_name} ${rw_mode} ${numjobs} ${iodepth} ${bs_num}
            sleep 5
        done
    done
done


-----------------------------------------------------------------------------------------

测试脚本：
#!/bin/bash

disk_name=''
for i in $(lsblk |grep disk|awk '{print $1}')
do
    disk_type=$(lsblk -o NAME,FSTYPE|grep $i|awk '{print $2}')
    disk_info=$(lsblk -o NAME,SIZE|grep $i)
    if [  "${disk_type}" == '' ];then
        disk_type='未格式化'
        disk_name="$disk_name $(echo "$disk_info" |awk '{print $1}')"
    fi
done
PS3="请选择磁盘序列数字:"
#disk_name=$(lsblk|grep disk|awk '{printf $1" "}')
num=1
if [ -z "$disk_name" ];then echo '系统上没有可测试的卷!...';exit 0;fi
select choice in $disk_name Quit
do
    case $choice in
        $choice)
            if [ "$choice" == "Quit" ];then
                exit 0
            elif [ -n "$choice" ];then
                disk_name="$choice"
                break
            elif [ -z "$choice" ];then
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
echo "fio 将开始对 $disk_name 磁盘进行测试！..."
