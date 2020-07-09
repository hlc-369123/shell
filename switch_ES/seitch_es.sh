#!/bin/bash
set -e -o pipefail

show_usage() {
    echo -e "Usage :\n \n--user \t\t\tuser name [\$XMS_USERNAME] \n--password \t\tuser password [\$XMS_PASSWORD] \n--action \t\t<disable/enable>\n"
    echo -e "\ne.g : \n\n$0 --user [\$XMS_USERNAME] --password [\$XMS_PASSWORD] <disable/enable>\n"
}

userinfo(){
    local user_par=$1
    local userinfo=$2
    echo "${user_par}"|awk -F "${userinfo}" '{print $2}'|awk '{print $1}'
}

if [ "$1" == "-h" ]; then
    show_usage
    exit 0
elif [ -z $XMS_USERNAME ];then 
    if [ "$1" == "-h" ]; then
            show_usage
            exit 0
    elif [ $# -lt 6 -o $# -gt 6 ]; then
            show_usage
            exit 0
    else
            user=$(userinfo "$*" --user)
            password=$(userinfo "$*" --password)
            action=$(userinfo "$*" --action)
            xms-cli="xms-cli --user ${user} --password ${password}"
            if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
    fi
elif [ -n $XMS_USERNAME -o $# -eq 6 ];then
    user=$(userinfo "$*" --user)
    password=$(userinfo "$*" --password)
    action=$(userinfo "$*" --action)
    xms-cli="xms-cli --user ${user} --password ${password}"
    if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
elif [ $# -lt 2 -o $# -gt 2 ]; then
    show_usage
    exit 0
else
    action=$1
    if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
fi

#echo "$user,$password,$action"
if [ $action == disable ];then
    xms-cli -l cluster set elasticsearch--enabled=false
    for i in {0..9}
    do
        es_stat=$(xms-cli -l cluster show elasticsearch|grep elasticsearch_enabled|awk '{print $4}')
        true_num=$(xms-manage db trigger list|grep true|wc -l)
        if [ $es_stat == 'false' -o $true_num == '0' ];then
            for ip in $host_ips; do
                log "Set config of xmsd on $ip..."
                $SSH $ip systemctl restart xmsd.service
                $SSH $ip systemctl status xmsd.service
            done
            break
        fi
    sleep 5
    done
fi




---------------------------------------------

#!/bin/bash
set -e -o pipefail

show_usage() {
    echo -e "Usage: \n\t$0 <--user USER --password PASSWORD>\n"
    echo -e "EG: $0 /dev/sdj\n"
}
if [ $# -lt 1 -o $# -gt 1 ]; then
	show_usage
	exit 0
elif [ "$1" == "-h" ]; then
	show_usage
	exit 0
elif [[ $1 == /dev/* ]]; then
	echo -e "block device $1\n"
else
	show_usage
        exit 0
fi

用户名/密码
disable/enable

BASEPATH=$(dirname $(dirname $(readlink -f ${BASH_SOURCE[0]})))

xms-cli --user admin --password admin-l cluster set elasticsearch--enabled=false

xms-cli --user admin --password admin -l cluster show elasticsearch

xms-manage db trigger list

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO]" "$@"
}

ssh_port=22
if [[ -n $1 ]]; then
    ssh_port=$1
fi
SSH="ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $ssh_port"

host_ips=$(xms-manage db list | awk '{print $1}')
if [[ -z $host_ips ]]; then
    fatal "Failed to get admin host ips"
fi

log "Disable xmsd indexing docs..."
for ip in $host_ips; do
    log "Set config of xmsd on $ip..."
    $SSH $ip systemctl restart xmsd.service
    $SSH $ip systemctl status xmsd.service
done
刷新角色
