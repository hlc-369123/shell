#/bin/bash

echo -e "==>将可执行文件目录添加到 PATH 环境变量中:"
echo 'PATH=/opt/k8s/bin:$PATH' >>/root/.bashrc
source /root/.bashrc

echo -e "==>停止并清除防火墙:"
systemctl stop firewalld.service
systemctl disable firewalld.service
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
iptables -P FORWARD ACCEPT

echo "==>关闭SWAP分区:"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "==>关闭SELINUX:"
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

echo "==>避免占用127.0.0.1:"
systemctl stop dnsmasq
systemctl disable dnsmasq

echo "==>加载模块:"
modprobe ip_vs_rr
modprobe br_netfilter

echo "==>优化内核参数:"
cat > kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.tcp_tw_recycle = 0
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576
fs.file-max = 52706963
fs.nr_open = 52706963
net.ipv6.conf.all.disable_ipv6 = 1
net.netfilter.nf_conntrack_max = 2310720
EOF
cp kubernetes.conf  /etc/sysctl.d/kubernetes.conf
sysctl -p /etc/sysctl.d/kubernetes.conf

echo "==>修改系统语言为英语:"
localectl status |grep en_US
if [ $? -gt 0 ]; then
    localectl  set-locale LANG=en_US.UTF-8
fi

echo "==>修改时区为上海:"
timedatectl status|grep -i shanghai
if [ $? -gt 0 ]; then
    timedatectl set-timezone Asia/Shanghai
fi

echo "==>停掉NetworkManager.service:"
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service

 
echo "==>加快ssh连接速度:"
sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
systemctl restart sshd

echo "==>将当前的 UTC 时间写入硬件时钟:"
timedatectl set-local-rtc 0

echo "==>重启依赖于系统时间的服务:"
systemctl restart rsyslog 
systemctl restart crond

echo "==>停止无关的服务:"
systemctl stop postfix && systemctl disable postfix

echo "==>持久化保存日志的目录:"
mkdir /var/log/journal
mkdir /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-prophet.conf <<EOF
[Journal]
# 持久化保存到磁盘
Storage=persistent

# 压缩历史日志
Compress=yes

SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000

# 最大占用空间 10G
SystemMaxUse=10G

# 单日志文件最大 200M
SystemMaxFileSize=200M

# 日志保存时间 2 周
MaxRetentionSec=2week

# 不将日志转发到 syslog
ForwardToSyslog=no
EOF
systemctl restart systemd-journald

mkdir -p  /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert


rm -f /etc/yum.repos.d/*
cat > /etc/yum.repos.d/local_base.repo <<EOF
[local]
name=local
baseurl=file://`pwd`/packages
enable=1
gpgcheck=0
EOF

echo "==>安装docker:"
yum install -y conntrack ntpdate ntp ipvsadm ipset jq iptables curl sysstat libseccomp wget yum-utils device-mapper-persistent-data lvm2
yum install -y --setopt=obsoletes=0 docker-ce-18.06.1.ce-3.el7
systemctl start docker;systemctl enable docker

echo "==>Docker从1.13版本开始调整了默认的防火墙规则，禁用了iptables filter表中FOWARD链，这样会引起Kubernetes集群中跨Node的Pod无法通信，因此docker安装完成后，还需要手动修改iptables规则:"
sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service

echo "==>docker加速/修改Driver为cgroupfs:"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://q2hy3fzi.mirror.aliyuncs.com"],
  "graph": "/tol/docker-data"
}
{  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
  "max-size": "100m"
  },
    "storage-driver": "overlay2"
  }
EOF

systemctl daemon-reload
systemctl restart docker
systemctl status docker 
