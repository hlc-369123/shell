#!/bin/bash
# ./manag_utili.sh start $vdfile && ./manag_utili.sh stop

utili_name='get_resource-utilization.sh'
if [ ! -f ${utili_name} ]
then
echo "未能获取${utili_name}！！！"
exit 1
fi

signal=$1
for storename in $(cat /etc/hosts|grep -v localhost|awk '{print $2}')
do
if [[ $signal == 'start' ]]
then
vdfile=$2
scp ${utili_name} ${storename}:/tmp/
ssh ${storename} /bin/bash /tmp/${utili_name} start $vdfile
elif [[ $signal == 'stop' ]]
then
ssh ${storename} /bin/bash /tmp/${utili_name} stop
fi
done
