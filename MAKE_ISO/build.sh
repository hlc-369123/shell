#!/bin/sh

#返回非零时退出
set -e -o pipefail

source ./config
#TARGET_PREFIX="http://gitbuilder.xsky.com/os-images"
#BOA_PREFIX="http://gitbuilder.xsky.com/boa-rpm-centos7-x86_64-basic/ref"
#RELEASE_PREFIX="http://release.xsky.com"
#BASE_ISO=CentOS-7-x86_64-DVD-1810.iso
#MD5SUM_FILE=md5.txt
#PASSWORD=Password@_
#BOA_CONF="/etc/boa.conf"
#HOSTNAME=xscaler
#XS_PREFIX=sds-oem-xe-2000-installer-
#ROOT_DRIVER_SIZE=222
#ISO_VOLUME_ID=XSCALER
#HOSTNAME_FILE="/etc/hostname"
#INSTALLER_DIR="/opt/xscaler/installer"
#ISO_VERSION_DIR="/opt/xscaler"
#ISO_VERSION_FILE="/etc/iso-version"
#PRODUCT_MODEL_FILE="/etc/xs-product-model"

source ./VERSION
## installer version
#XS_VERSION=XS_4.2.200.0.200623

## iso version
#ISO_VERSION=XS_4.2.200.0.200623

## boa version
#BOA_VERSION=XS_4.2.200.0.200622

## os release name and version
#OS_NAME="XSKY SDS OS"
#OS_NAME_ID="xsky-sds-os" # can contain only 0-9, a-z, '.', '_', '-'
#OS_VERSION=4.2
#OS_VERSION_ID=4.2        # can contain only 0-9, a-z, '.', '_', '-'

BASE_DIR=`pwd`
TMPL_DIR=${BASE_DIR}/templates
BIN_DIR=${BASE_DIR}/common/bin/

CACHE_DIR=${BASE_DIR}/cache
BASE_ISO_FILE=${CACHE_DIR}/${BASE_ISO}
BOOT_DIR=${CACHE_DIR}/bootiso
SOFTWARE_DIR=${BOOT_DIR}/software

plog() { echo "["$(date -u +"%Y-%m-%dT%H:%M:%SZ")"]" "$@"; }

prepare() {
    if ! rpm -q isomd5sum &> /dev/null; then
        yum -y install isomd5sum
    fi
    if ! rpm -q genisoimage &> /dev/null; then
        yum -y install genisoimage
    fi
    if ! rpm -q syslinux &> /dev/null; then
        yum -y install syslinux
    fi
}

get_base_iso() {
    plog "Check or load base ISO $BASE_ISO."
    local url=${TARGET_PREFIX}/${BASE_ISO}
    if [[ ! -e $BASE_ISO_FILE ]]; then
        plog "Base ISO $BASE_ISO not exist, load it."
        wget $url -P $CACHE_DIR
    else
        checkisomd5 $BASE_ISO_FILE > /dev/null
        if [[ $? != 0 ]]; then
            plog "Check md5 of Base ISO failed, reload it."
            rm -f $BASE_ISO_FILE
            wget $url -P $CACHE_DIR
        fi
    fi
}

init_boot_dir() {
    local tmp_dir=$CACHE_DIR/tmpiso
    mkdir -p $tmp_dir
    plog "Command: mount -o loop $BASE_ISO_FILE $tmp_dir"
    if grep -qs $tmp_dir /proc/mounts; then
        umount $tmp_dir
    fi
    mount -o loop $BASE_ISO_FILE $tmp_dir

    mkdir -p $BOOT_DIR
    plog "Command: cp -r ${tmp_dir}/* ${BOOT_DIR}/"
    cp -r ${tmp_dir}/* ${BOOT_DIR}/
    chmod -R u+w ${BOOT_DIR}

    umount $tmp_dir
    rm -rf $tmp_dir
}

load_installer() {
    plog "Check and download xscaler intalller"
    local software_dir=$1
    local installer_dir=${CACHE_DIR}/${XS_VERSION}
    local installer_file=${installer_dir}/${XS_PREFIX}${XS_VERSION}.tar.gz
    local installer_sha256=${installer_dir}/sha256sum.txt

    local dot_count=$(echo ${XS_VERSION} | grep -o '\.' | wc -l)
    local release_url
    if [[ $dot_count -gt 3 ]]; then
        release_url=${RELEASE_PREFIX}/dev
    else
        release_url=${RELEASE_PREFIX}
    fi

    local file_url="${release_url}/${XS_VERSION}/${XS_PREFIX}${XS_VERSION}.tar.gz"
    local sha256_url="${release_url}/${XS_VERSION}/sha256sum.txt"
    mkdir -p ${installer_dir}
    if [[ ! -e $installer_file ]]; then
        plog "Download ${installer_file} from ${file_url}"
        plog "Command: wget $file_url -P $installer_dir"
        wget $file_url -P $installer_dir
    fi
    if [[ ! -e $installer_sha256 ]]; then
        plog "Download sha256sum.txt to veriry isntaller file."
        plog "Command: wget $sha256_url -P $installer_dir."
        wget $sha256_url -P $installer_dir
    fi

    cd $installer_dir
    sha256sum -c $installer_sha256
    if [[ $? != 0 ]]; then
        plog "Sha256 verify failed, will download tar file again."
        rm -f *
        plog "Command: wget $file_url"
        wget $file_url
        plog "Command: wget $sha256_url"
        wget $sha256_url
    fi
    cd -

    plog "Command: cp $installer_file $installer_sha256 ${software_dir}/"
    cp $installer_file $installer_sha256 ${software_dir}/
}

generate_os_release() {
    local software_dir=$1
    local os_release_tmpl=${TMPL_DIR}/os-release.tmpl
    local os_release_file=${software_dir}/os-release

    cp $os_release_tmpl $os_release_file
    sed -i "s/OS_NAME_will_be_replaced/${OS_NAME}/g" $os_release_file
    sed -i "s/OS_NAME_ID_will_be_replaced/${OS_NAME_ID}/g" $os_release_file
    sed -i "s/OS_VERSION_will_be_replaced/${OS_VERSION}/g" $os_release_file
    sed -i "s/OS_VERSION_ID_will_be_replaced/${OS_VERSION_ID}/g" $os_release_file
}

load_boa_rpm() {
    local software_dir=$1
    local url_prefix=${BOA_PREFIX}/${BOA_VERSION}
    local suffix=$(curl ${url_prefix}/suffix)
    local url="${url_prefix}/x86_64/boa${suffix}"

    rm -f ${software_dir}/boa-*
    plog "Command: wget $url -P $software_dir"
        wget $url -P $software_dir
}

build_software() {
    mkdir -p $SOFTWARE_DIR
    rm -rf $SOFTWARE_DIR/*

    load_installer $SOFTWARE_DIR
    load_boa_rpm $SOFTWARE_DIR
    generate_os_release $SOFTWARE_DIR

    cp -a $BASE_DIR/patches/*.rpm $SOFTWARE_DIR
}

generate_iso_linux() {
    local isolinux_dir=${BOOT_DIR}/isolinux
    local isolinux_file=${isolinux_dir}/isolinux.cfg

    plog "Config kickstart and isolinux file"
    cp -f ${TMPL_DIR}/splash.png ${isolinux_dir}/splash.png
    cp -f ${TMPL_DIR}/isolinux.cfg.tmpl $isolinux_file

    sed -i "s#ISO_VOLUME_ID_will_be_replaced#${ISO_VOLUME_ID}#g" $isolinux_file
    sed -i "s#XS_VERSION_will_be_replaced#${XS_VERSION}#g" $isolinux_file
}

generate_kickstart() {
    local ks_tmpl=${TMPL_DIR}/ks.cfg.tmpl
    local ks_file=${BOOT_DIR}/isolinux/ks.cfg
    local ks_parted_file=${BOOT_DIR}/isolinux/ks-parted.cfg
    local ks_file_xe2020=${BOOT_DIR}/isolinux/ks-xe2020.cfg
    local ks_file_xe2030=${BOOT_DIR}/isolinux/ks-xe2030.cfg
    local ks_file_xe2050=${BOOT_DIR}/isolinux/ks-xe2050.cfg
    local ks_file_xe2120=${BOOT_DIR}/isolinux/ks-xe2120.cfg
    local ks_file_xe2130=${BOOT_DIR}/isolinux/ks-xe2130.cfg
    local ks_file_xe3150=${BOOT_DIR}/isolinux/ks-xe3150.cfg
    local ks_file_xe3160=${BOOT_DIR}/isolinux/ks-xe3160.cfg
    local ks_file_xe3180=${BOOT_DIR}/isolinux/ks-xe3180.cfg
    local ks_file_x3000=${BOOT_DIR}/isolinux/ks-x3000.cfg
    local passwd_crypted=`${BIN_DIR}/crypt --sha-512 --password $PASSWORD`

    plog "Config kickstart and isolinux file"
    cp -f ${TMPL_DIR}/ks.cfg.tmpl $ks_file

    sed -i "s#ROOT_DRIVER_SIZE_will_be_replaced#${ROOT_DRIVER_SIZE}#g" $ks_file
    sed -i "s#XS_PREFIX_will_be_replaced#${XS_PREFIX}#g" $ks_file
    sed -i "s#HOSTNAME_will_be_replaced#${HOSTNAME}#g" $ks_file
    sed -i "s#HOSTNAME_FILE_will_be_replaced#${HOSTNAME_FILE}#g" $ks_file
    sed -i "s#INSTALLER_DIR_will_be_replaced#${INSTALLER_DIR}#g" $ks_file
    sed -i "s#ISO_VERSION_will_be_replaced#${ISO_VERSION}#g" $ks_file
    sed -i "s#ISO_VERSION_DIR_will_be_replaced#${ISO_VERSION_DIR}#g" $ks_file
    sed -i "s#ISO_VERSION_FILE_will_be_replaced#${ISO_VERSION_FILE}#g" $ks_file
    sed -i "s#PRODUCT_MODEL_FILE_will_be_replaced#${PRODUCT_MODEL_FILE}#g" $ks_file
    sed -i "s#ISO_VOLUME_ID_will_be_replaced#${ISO_VOLUME_ID}#g" $ks_file
    sed -i "s#PASSWORD_will_be_replaced#${PASSWORD}#g" $ks_file
    sed -i "s#PASSWORD_CRYPTED_will_be_replaced#rootpw --iscrypted ${passwd_crypted}#g" $ks_file
    sed -i "s#OS_NAME_will_be_replaced#${OS_NAME}#g" $ks_file
    sed -i "s#OS_VERSION_will_be_replaced#${OS_VERSION}#g" $ks_file
    sed -i "s#BOA_CONF_will_be_replaced#${BOA_CONF}#g" $ks_file

    cp $ks_file $ks_parted_file
    sed -i "s#CHECK_PARTED_will_be_replaced#uncheck#g" $ks_file
    sed -i "s#CHECK_PARTED_will_be_replaced#check#g" $ks_parted_file

    cp $ks_file $ks_file_xe2020
    cp $ks_file $ks_file_xe2030
    cp $ks_file $ks_file_xe2050
    cp $ks_file $ks_file_xe2120
    cp $ks_file $ks_file_xe2130
    cp $ks_file $ks_file_xe3150
    cp $ks_file $ks_file_xe3160
    cp $ks_file $ks_file_xe3180
    cp $ks_file $ks_file_x3000
    rm $ks_file $ks_parted_file

    # xe2020
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE2020#g" $ks_file_xe2020
    sed -i "s#CPUCores_will_be_replaced#8#g" $ks_file_xe2020
    sed -i "s#MemorySize_will_be_replaced#32G#g" $ks_file_xe2020
    sed -i "s#SSDNum_will_be_replaced#1#g" $ks_file_xe2020
    sed -i "s#HDDNum_will_be_replaced#5#g" $ks_file_xe2020
    sed -i "s#NIC1GPorts_will_be_replaced#4#g" $ks_file_xe2020

    # xe2030
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE2030#g" $ks_file_xe2030
    sed -i "s#CPUCores_will_be_replaced#16#g" $ks_file_xe2030
    sed -i "s#MemorySize_will_be_replaced#64G#g" $ks_file_xe2030
    sed -i "s#SSDNum_will_be_replaced#1#g" $ks_file_xe2030
    sed -i "s#HDDNum_will_be_replaced#5#g" $ks_file_xe2030
    sed -i "s#NIC1GPorts_will_be_replaced#4#g" $ks_file_xe2030

    # xe2050
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE2050#g" $ks_file_xe2050
    sed -i "s#CPUCores_will_be_replaced#16#g" $ks_file_xe2050
    sed -i "s#MemorySize_will_be_replaced#128G#g" $ks_file_xe2050
    sed -i "s#SSDNum_will_be_replaced#2#g" $ks_file_xe2050
    sed -i "s#HDDNum_will_be_replaced#5#g" $ks_file_xe2050
    sed -i "s#NIC1GPorts_will_be_replaced#4#g" $ks_file_xe2050

    # xe2120
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE2120#g" $ks_file_xe2120
    sed -i "s#CPUCores_will_be_replaced#8#g" $ks_file_xe2120
    sed -i "s#MemorySize_will_be_replaced#32G#g" $ks_file_xe2120
    sed -i "s#SSDNum_will_be_replaced#1#g" $ks_file_xe2120
    sed -i "s#HDDNum_will_be_replaced#5#g" $ks_file_xe2120
    sed -i "s#NIC1GPorts_will_be_replaced#2#g" $ks_file_xe2120

    # xe2130
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE2130#g" $ks_file_xe2130
    sed -i "s#CPUCores_will_be_replaced#16#g" $ks_file_xe2130
    sed -i "s#MemorySize_will_be_replaced#64G#g" $ks_file_xe2130
    sed -i "s#SSDNum_will_be_replaced#1#g" $ks_file_xe2130
    sed -i "s#HDDNum_will_be_replaced#5#g" $ks_file_xe2130
    sed -i "s#NIC1GPorts_will_be_replaced#2#g" $ks_file_xe2130

    # xe3150
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE3150#g" $ks_file_xe3150
    sed -i "s#CPUCores_will_be_replaced#20#g" $ks_file_xe3150
    sed -i "s#MemorySize_will_be_replaced#96G#g" $ks_file_xe3150
    sed -i "s#SSDNum_will_be_replaced#2#g" $ks_file_xe3150
    sed -i "s#HDDNum_will_be_replaced#10#g" $ks_file_xe3150
    sed -i "s#NIC1GPorts_will_be_replaced#2#g" $ks_file_xe3150

    # xe3160
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE3160#g" $ks_file_xe3160
    sed -i "s#CPUCores_will_be_replaced#24#g" $ks_file_xe3160
    sed -i "s#MemorySize_will_be_replaced#96G#g" $ks_file_xe3160
    sed -i "s#SSDNum_will_be_replaced#2#g" $ks_file_xe3160
    sed -i "s#HDDNum_will_be_replaced#10#g" $ks_file_xe3160
    sed -i "s#NIC1GPorts_will_be_replaced#2#g" $ks_file_xe3160

    # xe3180
    sed -i "s#PRODUCT_MODEL_will_be_replaced#XE3180#g" $ks_file_xe3180
    sed -i "s#CPUCores_will_be_replaced#32#g" $ks_file_xe3180
    sed -i "s#MemorySize_will_be_replaced#128G#g" $ks_file_xe3180
    sed -i "s#SSDNum_will_be_replaced#2#g" $ks_file_xe3180
    sed -i "s#HDDNum_will_be_replaced#10#g" $ks_file_xe3180
    sed -i "s#NIC1GPorts_will_be_replaced#2#g" $ks_file_xe3180

    # x3000
    sed -i "s#PRODUCT_MODEL_will_be_replaced#X3000#g" $ks_file_x3000
    sed -i "s#CPUCores_will_be_replaced#20#g" $ks_file_x3000
    sed -i "s#MemorySize_will_be_replaced#96G#g" $ks_file_x3000
    sed -i "s#SSDNum_will_be_replaced#2#g" $ks_file_x3000
    sed -i "s#HDDNum_will_be_replaced#10#g" $ks_file_x3000
    sed -i "s#NIC1GPorts_will_be_replaced#4#g" $ks_file_x3000
}

build_packages() {
    cd $BOOT_DIR
    rm -f Packages/boa-*
    plog "Downlaod boa RPM"
    local url_prefix=${BOA_PREFIX}/${BOA_VERSION}
    local suffix=$(curl ${url_prefix}/suffix)
    wget ${BOA_PREFIX}/${BOA_VERSION}/x86_64/boa-${suffix}
    rm -rf repodata
    createrepo -g ${TMPL_DIR}/comps.xml.tmpl .
    cd -
}

make_iso() {
    local target_dir=${BASE_DIR}/build/xscaler-${ISO_VERSION}
    local target=${target_dir}/xscaler-${ISO_VERSION}.iso
    mkdir -p $target_dir

    cd $BOOT_DIR
    plog "Make ISO ${target}"
    mkisofs -o $target -log-file ../mkisofs.log -input-charset utf-8  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "${ISO_VOLUME_ID}" -R -J -v -T -verbose .
    cd -

    plog "Command: isohybrid $target"
    isohybrid $target

    plog "Command: implantisomd5 $target"
    implantisomd5 $target
    md5sum $target > ${target_dir}/md5.txt

    size=$(du -bh ${target}|awk '{print $1}')
    plog "ISO=${target}, size $size."
}


build_iso() {
    plog "Beginnig build ISO"

    # get build environment ready
    prepare

    # check or download base iso
    get_base_iso

    # init boot dir for making iso
    init_boot_dir

    # generate isolinux file
    generate_iso_linux

    # generate kickstart file
    generate_kickstart

    # config install Packages
    # build_packages

    # build customization software
    build_software

    # make iso
    make_iso

    plog "Complete building ISO"
}

build_iso
