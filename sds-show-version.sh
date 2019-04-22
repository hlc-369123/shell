#!/bin/bash

# Coloring
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
CYAN=$'\033[35m'
DARKGREEN=$'\033[36m'
COLORRESET=$'\033[0m' # reset the foreground colour
declare -A COLORMAP=( \
	[os]=${YELLOW} \
	[installer]=${RED} \
	[xms]=${BLUE} \
	[ceph]=${RED} \
	[xdc]=${GREEN} \
	[rgw]=${BLUE} \
	[docker]=${CYAN} \
	[openstack]=${RED} \
	[zstack]=${CYAN} \
	[libvirt]=${YELLOW} \
	)


VERSION='v0.2'
colorful=''
default_color=''

function print_version() {
	echo "Version: ${VERSION}"
}

function print_usage() {

	cat <<-EOF

Usage: sds-show-version

    -c, --color   Colorful output
    -h, --help    Display this information
    -v, --version Display version

EOF
}

function parse_args() {
	if [[ ! "$@" =~ ^\-.+ ]]; then
		return
	fi
	ARGS=$(getopt -o chv -l color,help,version -- "$@")
	if [[ $? -ne 0 ]]; then
		show_usage
		exit 1
	fi

	eval set -- "${ARGS}"

	while true; do
		case "${1}" in
			-c | --color)
				colorful=1
				shift
				;;
			-v | --version)
				print_version
				exit 0
				;;
			-h | --help)
				print_usage
				exit 0
				;;
			--)
				shift
				break
				;;
			*)
				show_usage
				exit 1
				;;
		esac
	done
}

function set_color() {
	if [[ -n ${1} ]]; then
		default_color=${1}
	fi
}

function reset_color() {
	default_color=''
}

function colorful_msg() {
	local msg=${1}
	local color=${2:-${default_color}}
	if [[ ${colorful} -eq 1 ]]; then
		echo -e -n ${color}${msg}${COLORRESET}
	else
		echo -e -n ${msg}
	fi
}

function log::info() {
	for message; do
		colorful_msg "${message}"
	done
	echo
}

function component_title() {
	local name=${1}
	log::info '======================================================================'
	log::info "\t${name}"
	log::info '======================================================================'
}

function subcomponent_title() {
	local name=${1}
	log::info '\n----------------------------------------'
	log::info "\t${name}"
	log::info '----------------------------------------\n'
}

function show_rpm_version() {
	local pkg=${1}
	local do_grep=${2}
	rpm -q ${pkg} 2> /dev/null
	if [[ $? -ne 0 || -n ${do_grep} ]]; then
		rpm -qa | grep ${pkg}
	fi
}

function grep_option() {
	local file=${1}
	local pattern=${2}
	log::info "\ngrep ${pattern} in ${file}\n"
	if [[ -n ${pattern} ]]; then
		egrep -v '^#|^$' ${file} | grep ${pattern}
	else
		egrep -v '^#|^$' ${file}
	fi
}

function show_version::os() {
	component_title "OS"
	cat /etc/centos-release
	cat /etc/redhat-release
	uname -a
}

function show_version::docker() {
	component_title "Docker"
	docker version
	cat /etc/docker/daemon.json
}

function show_version::installer() {
	component_title "Installer"
	cat /opt/sds/installer/VERSION
}

function show_version::xms() {
	component_title "xms"
	xms-cli --version
	show_rpm_version xms
}

function show_version::ceph() {
	component_title "Ceph"
	ceph --version
	show_rpm_version ceph all
}

function show_version::xdc() {
	component_title "XDC"
	show_rpm_version xdc

	subcomponent_title "MD5 sum of kernel module"
	md5sum /opt/sds/xdc/block/rbd.ko
	for f in $(ls /opt/sds/xdc/target/*.ko); do
		md5sum ${f}
	done

	subcomponent_title "lsmod"
	lsmod | egrep 'btree|qla|target|tcm|iscsi|vhost'

	subcomponent_title "ceph.conf proxy"
	grep 'xdc_proxy' /etc/ceph/ceph.conf

	subcomponent_title "xdc.conf"
	grep_option /etc/xdc/xdc.conf
}

function show_version::rgw() {
	component_title "RGW"
	show_rpm_version radosgw all
	show_rpm_version rgw all
}

function show_version::openstack() {
	component_title "OpenStack"

	subcomponent_title "Nova"
	show_rpm_version nova

	subcomponent_title "Cinder"
	show_rpm_version cinder
	grep_option /etc/cinder/cinder.conf 'rbd'

	subcomponent_title "Glance"
	show_rpm_version glance
	grep_option /etc/glance/glance.conf 'rbd'
}

function show_version::zstack() {
	component_title "ZStack"

	cat /etc/zstack-release
	zstack-ctl status
	show_rpm_version zstack all
}

function show_version::libvirt() {
	component_title "libvirt"

	subcomponent_title "libvirt"
	show_rpm_version libvirt all

	subcomponent_title "qemu"
	show_rpm_version qemu all
}

function show_version::upgrade() {
	component_title "Upgrade"

	subcomponent_title "To v3.2"
	awk '/installed version/,/Upgrading from/' /var/log/sds-installer/upgrade.log

	subcomponent_title "To v4"
	upgrade_dir="/opt/sds/upgrade-files"
	if [[ ! -d ${upgrade_dir} ]]; then
		return
	fi
	for each_upgrade in $(ls ${upgrade_dir}); do	
		awk '/installed version/,/Upgrading from/' ${upgrade_dir}/${each_upgrade}/upgrade.log
	done
}

function show_version() {
	local name=${1}
	set_color ${COLORMAP[${name}]}
	eval "show_version::${name}"
	echo
}

function main() {
	set_color ${BLUE}
	component_title "sds show version begin (VERSION: ${VERSION})"
	component_title "$(date)"
	for component in os docker \
		installer xms ceph xdc rgw \
		openstack zstack libvirt \
		upgrade
	do
		show_version ${component}
	done

	set_color ${YELLOW}
	component_title "$(date)"
	component_title "sds show version finished (VERSION: ${VERSION})"
}

parse_args "$@"
main
