#!/bin/bash
set -e -o pipefail
shopt -s  expand_aliases

ssh_port=22
SSH="ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $ssh_port"

host_ips=$(xms-manage db list 2>/dev/null| awk '{print $1}')
if [[ -z $host_ips ]]; then
    fatal "Failed to get admin host ips"
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO]" "$@"
}

show_usage() {
    echo -e "Usage :\n \n--user \t\t\tuser name [\$XMS_USERNAME] \n--password \t\tuser password [\$XMS_PASSWORD] \n--action \t\t<disable/enable>\n"
    echo -e "\ne.g : \n\n$0 --user [\$XMS_USERNAME] --password [\$XMS_PASSWORD] --action <disable/enable>\n"
}

userinfo(){
    local user_par=$1
    local userinfo=$2
    echo "${user_par}"|awk -F "${userinfo}" '{print $2}'|awk '{print $1}'
}

check_self_login() {
    local local_admin_ip=$1
    $SSH ${local_admin_ip} hostname &> /dev/null
    if [[ $? -ne 0 ]]; then
        log "${local_admin_ip} ssh failed !..."
        exit 1
    fi
}

es_action(){
  local action=$1
  local enabled=$2
  if [ -n $enabled ];then enabled="--enabled=$enabled";fi
  xms-cli -l cluster $action elasticsearch $enabled
}

refresh_the_role(){
  local host_ips=$1
  for ip in $host_ips; do
    check_self_login $ip
    log "restart of xmsd on $ip..."
    $SSH $ip systemctl restart xmsd.service
    sleep 5
    xmsd_status=$($SSH $ip systemctl is-active xmsd.service)
    if [ $xmsd_status == 'active' ];then
      log "$ip xmsd is active,Refresh the role..."
      node_id=$(xms-cli host list|grep $ip|awk '{print $2}')
      node_roles=$(xms-cli host show $node_id|grep "roles"|awk '{print $4}')
      xms-cli host set --roles $node_roles $node_id
    else
      log "$ip Xmsd  state failed, Please check it !..."
      systemctl status xmsd.service
      exit 1
    fi
  done
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
            alias xms-cli='xms-cli --user $user --password $password'
            if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
    fi
elif [ -n $XMS_USERNAME -o $# -eq 6 ];then
    user=$(userinfo "$*" --user)
    password=$(userinfo "$*" --password)
    action=$(userinfo "$*" --action)
    alias xms-cli='xms-cli --user $user --password $password'
    if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
elif [ $# -lt 2 -o $# -gt 2 ]; then
    show_usage
    exit 0
else
    action=$1
    if ! xms-cli host list &>/dev/null;then echo 'Wrong information...'&&exit 1;fi
fi

if [ $action == disable ];then
    es_action set false
    for i in {0..9};do
        es_stat=$(es_action show|grep elasticsearch_enabled|awk '{print $4}')
        true_num=$(xms-manage db trigger list|grep true|wc -l)
        if [ $es_stat == 'false' -o $true_num == '0' ];then
            break
        elif [ $i -eq 9 -o $es_stat == 'false' -o $true_num == '0' ]; then
          log "ES $action failed,Please check it !..."
          exit 1
        else
          sleep 5
        fi
    done
    refresh_the_role host_ips
fi
