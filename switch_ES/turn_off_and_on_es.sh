#!/bin/bash
set -e -o pipefail

ssh_port=22
SSH="ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p ${ssh_port}"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S')" "[INFO]" "$@"
}

warnlog() {
  local log_info=$@
  echo -e ""$(date '+%Y-%m-%d %H:%M:%S')" "[WARN]" \033[1;31m${log_info}\033[0m"
}

get_admin_ip() {
  host_ips=$(xms-manage db list 2>/dev/null | awk '{print $1}')
  if [[ -z "${host_ips}" ]]; then
    warnlog "Failed to get admin host ips"
  fi
  log "Get admin host ips:"
  echo "$host_ips"
}

show_usage() {
  echo -e "Usage :\n \n--user \t\t\tuser name [\$XMS_USERNAME] \n--password \t\tuser password [\$XMS_PASSWORD] \n--action \t\t<disable/enable> to ES.\n"
  echo -e "\ne.g : \nUse the full command. \n\n$0 --user [\$XMS_USERNAME] --password [\$XMS_PASSWORD] --action <disable/enable>\n"
  echo -e "\ne.g : \nIf you configure '/etc/xms/xmsrc','source /etc/xms/xmsrc', you can avoid using '--user' and '--password'. \n\n$0  --action <disable/enable>\n"
}

userinfo() {
  local user_par=$1
  local userinfo=$2
  echo "${user_par}" | awk -F "${userinfo}" '{print $2}' | awk '{print $1}'
}

check_self_login() {
  local local_admin_ip=$1
  $SSH "${local_admin_ip}" hostname &>/dev/null
  if [[ $? -ne 0 ]]; then
    warnlog "${local_admin_ip} ssh failed !..." && exit 1
  fi
}

xms_cli_use() {
  local action=$1
  if [[ -n "${user}" && -n "${password}" ]]; then
    xms-cli --user "${user}" --password "${password}" ${action}
  else
    xms-cli ${action}
  fi
}

es_action() {
  local action=$1
  local enabled=$2
  if [[ -n "${enabled}" ]]; then enabled="--enabled=$enabled"; fi
  xms_cli_use "-l cluster $action elasticsearch $enabled"
}

check_xms_stat() {
  local ip=$1
  local service_name=$2
  local action=$3
  local repeat=$4
  local node_id=$(xms_cli_use "host list" | grep "${ip}" | awk '{print $2}')
  local node_roles=$(xms_cli_use "host show ${node_id}" | grep "roles" | awk '{print $4}')
  for i in {0..9}; do
    if [[ "${service_name}" == "Postgres_xmsd" ]]; then
      local active_stat=$(xms_cli_use "host show ${node_id}" | awk '/ status/{print $4}')
      if [[ "${i}" -eq 0 && "${active_stat}" == warning ]]; then
        xms_cli_use "host set --roles ${node_roles} ${node_id}" 1>/dev/null
      fi
    elif [[ "${service_name}" == "action_status" ]]; then
      local active_stat=$(xms_cli_use "host show ${node_id}" | grep action_status | awk '{print $4}')
      if [[ "${active_stat}" != "updating_host_roles" ]]; then active_stat="active"; fi
    fi
    local up_stat=$(xms_cli_use "host show ${node_id}" | awk '/up /{print $4}')
    if [[ "${active_stat}" == "active" && "${up_stat}" == "true" ]]; then
      break
    elif [[ "${i}" == '9' && "${active_stat}" != "active" && "${repeat}" == "true" ]]; then
      rebuild-ES "${action}"
      warnlog "$service_name status is $active_stat，Please check it！..." && exit 1
    else
      sleep 20
    fi
  done
}

rebuild-ES() {
  local action=$1
  if [[ "${action}" == "true" ]]; then
    read -p "If you want to rebuild the ES, type 'y' or 'yes': " if_rebuild
    if [[ "${if_rebuild}" == "y" || "${if_rebuild}" == "yes" ]]; then
      /opt/sds/installer/bin/rebuild-elasticsearch
      refresh_the_role "${host_ips}" "true" "false"
    fi
  else
    warnlog "ES mission execution failure,Please check it !..."
  fi
}

refresh_the_role() {
  local host_ips=$1
  local action=$2
  local repeat=$3
  for ip in ${host_ips}; do
    check_self_login "${ip}"
    log "Restart of xmsd on $ip..."
    $SSH "${ip}" systemctl restart xmsd.service 2>/dev/null
    local xmsd_status=$($SSH "${ip}" systemctl is-active xmsd.service 2>/dev/null)
    if [[ "${xmsd_status}" != 'active' ]]; then sleep 10; fi
  done
  for ip in ${host_ips}; do
    local xmsd_status=$($SSH "${ip}" systemctl is-active xmsd.service 2>/dev/null)
    if [[ "${xmsd_status}" == 'active' ]]; then
      log "$ip xmsd is active,Refresh the role..."
      local node_id=$(xms_cli_use "host list" | grep "${ip}" | awk '{print $2}')
      local node_roles=$(xms_cli_use "host show ${node_id}" | grep "roles" | awk '{print $4}')
      check_xms_stat "${ip}" "Postgres_xmsd" "${action}" "${repeat}"
      xms_cli_use "host set --roles ${node_roles} ${node_id}" 1>/dev/null
      check_xms_stat "${ip}" "action_status" "${action}" "${repeat}"
    else
      warnlog "$ip Xmsd  state failed, Please check it !..."
      systemctl status xmsd.service && exit 1
    fi
  done
}

action_es() {
  local action=$1
  es_action set "${action}" 1>/dev/null
  if [[ "${action}" == "false" ]]; then stst_action="true"; else stst_action="false"; fi
  for i in {0..9}; do
    log "Checking the results!..."
    es_stat=$(es_action show | grep elasticsearch_enabled | awk '{print $4}')
    true_num=1
    if ! xms-manage db trigger list 2>/dev/null | grep -o "${stst_action}" &>/dev/null; then true_num=0; fi
    if [[ "${es_stat}" == "${action}" && "${true_num}" == '0' ]]; then
      get_admin_ip
      refresh_the_role "${host_ips}" "${action}" "true"
      refresh_code=$?
      if ! xms_cli_use 'service list' | grep 'elasticsearch' | grep 'error' && [[ "${refresh_code}" -eq 0 ]]; then
        log "Successful execution of task ES !..." && exit 0
      else
        rebuild-ES "${action}"
        xms_cli_use "service list" | grep 'elasticsearch' | grep 'error'
        exit 1
      fi
    elif [[ $i -eq 9 && "${es_stat}" == "${action}" ]]; then
      rebuild-ES "${action}"
      exit 1
    else
      sleep 10
    fi
  done
}

if [ "$1" == "-h" ]; then
  show_usage
  exit 0
elif [ -z "${XMS_USERNAME}" ]; then
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
    if ! xms_cli_use "host list" &>/dev/null; then warnlog "Incorrect username or password information..." && exit 1; fi
  fi
elif [ -n "${XMS_USERNAME}" -o $# -eq 6 ]; then
  user=$(userinfo "$*" --user)
  password=$(userinfo "$*" --password)
  action=$(userinfo "$*" --action)
  if ! xms_cli_use "host list" &>/dev/null; then warnlog "Incorrect username or password information..." && exit 1; fi
elif [ $# -lt 2 -o $# -gt 2 ]; then
  show_usage
  exit 0
else
  action=$1
  if ! xms_cli_use "host list" &>/dev/null; then warnlog "Incorrect username or password information..." && exit 1; fi
fi

log "${action}ing ES!..."
if [ "${action}" == disable ]; then
  action_es false
elif [ "${action}" == enable ]; then
  action_es true
else
  show_usage
  exit 0
fi
