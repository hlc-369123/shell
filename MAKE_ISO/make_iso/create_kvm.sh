#!/bin/bash

kvm_virtual_name="XS-76-test"
sys_disk_name="${kvm_virtual_name}.qcow2"
sys_disk_size="110"
memory="4"
cpu_num="4"

memory=$((${memory}*1024))
mkdir -p /opt/data
virsh destroy ${kvm_virtual_name}
virsh undefine ${kvm_virtual_name}
rm -f /opt/data/${sys_disk_name}

qemu-img create -f qcow2  /opt/data/${sys_disk_name} "${sys_disk_size}G"
virt-install \
--virt-type kvm \
--name ${kvm_virtual_name} \
--ram ${memory} \
--vcpu ${cpu_num} \
--cdrom=/opt/make_iso/XOS-7.6-x86_64-1810.iso \
--disk /opt/data/${sys_disk_name},format=qcow2 \
--network bridge=br0 \
--graphic vnc,listen=0.0.0.0 --noautoconsole
