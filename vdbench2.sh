#!/bin/bash

PATH=$(dirname $(readlink -f "$0"))
if [ ! -f $PATH/get_water ];then
echo '未能获取get_water！！！'
exit 1
fi
flush_water(){
supervise_node=node2  #node2为检测水位节点
scp get_water ${supervise_node}:/root/ 1>/dev/null
flges='True'
while [ $flges == True ]
do
flge=$(ssh ${supervise_node} "/bin/bash /root/get_water")
if [ ${flge} == false ]
then
ceph tell osd.* injectargs '--mscache_flush_waterlevel 1'
sleep 1
else
flges='False'
fi
done
}

rm -f ./vdbench_test-file
for i in single_vol nude_vol mix_vol
do
ls $i|sort -n -k 1 >> ./vdbench_test-file
done

for i in $(cat ${PATH}/vdbench_test-file)
do
mode="read"
result=$(echo ${i} | grep "${mode}")
if [[ ${result} == "" ]]
then
flush_water
sleep 2
ceph tell osd.* injectargs '--mscache_flush_waterlevel 80'
sleep 1
fi
/root/vdbench50407/vdbench -f ${PATH}/${i}
sleep 3
tar -zcvf ${dir}/${i}.tar.gz /root/vdbench50407/output/
done
