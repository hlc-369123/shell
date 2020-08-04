#/bin/bash

echo "==>设置主机名:\n"
hostnamectl set-hostname k8s-master01

echo "==>添加本地解析:"
cat>>/etc/hosts<<EOF
1.1.1.14 k8s-master01
1.1.1.15 k8s-node01
1.1.1.16 k8s-node02
EOF

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


echo -e "==>配置yum源:"
rm -f /etc/yum.repos.d/*.repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo 1>/dev/null
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo 1>/dev/null
wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 1>/dev/null

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=0
EOF

yum makecache fast


echo "==>安装docker:"
yum install -y yum-utils device-mapper-persistent-data lvm2 1>/dev/null
yum list docker-ce.x86_64 --showduplicates |sort -r 1>/dev/null
yum install -y --setopt=obsoletes=0 docker-ce-18.06.1.ce-3.el7 1>/dev/null
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

echo "==>安装k8s工具:"
yum list kubelet kubeadm kubectl --showduplicates |sort -r 1>/dev/null
yum install kubelet-1.15.0 kubeadm-1.15.0 kubectl-1.15.0 -y 1>/dev/null

systemctl restart docker
systemctl status docker 
systemctl enable kubelet.service

echo "Pulling Images..."
echo "==>kube-apiserver:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver-amd64:v1.15.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver-amd64:v1.15.0 k8s.gcr.io/kube-apiserver:v1.15.0

echo "==>kube-controller-manager:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager-amd64:v1.15.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager-amd64:v1.15.0 k8s.gcr.io/kube-controller-manager:v1.15.0

echo "==>kube-scheduler:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler-amd64:v1.15.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler-amd64:v1.15.0 k8s.gcr.io/kube-scheduler:v1.15.0

echo "==>kube-proxy:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy-amd64:v1.15.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy-amd64:v1.15.0 k8s.gcr.io/kube-proxy:v1.15.0

echo "==>coredns:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1

echo "==>etcd:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/etcd-amd64:3.3.10
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/etcd-amd64:3.3.10 k8s.gcr.io/etcd:3.3.10

echo "==>pause:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1 k8s.gcr.io/pause:3.1

echo "==>kubernetes-dashboard:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1 k8s.gcr.io/kubernetes-dashboard:v1.10.1

echo "==>heapster:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-amd64:v1.5.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-amd64:v1.5.0 k8s.gcr.io/heapster-amd64:v1.5.0

echo "==>heapster-influxdb:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-influxdb-amd64:v1.5.2
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-influxdb-amd64:v1.5.2 k8s.gcr.io/heapster-influxdb-amd64:v1.5.2

echo "==>heapster-grafana:"
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-grafana-amd64:v5.0.4
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/heapster-grafana-amd64:v5.0.4 k8s.gcr.io/heapster-grafana-amd64:v5.0.4

echo "==>flannel:"
docker pull quay.io/coreos/flannel:v0.11.0-amd64

echo "==>清除无用的image:"
for i in `docker image ls |grep 'aliyuncs'|awk '{print $1":"$2}'`;do echo $i ;docker image rmi $i;done
