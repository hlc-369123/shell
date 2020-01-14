#!/bin/bash

sed -i s/keepcache=.*/keepcache=1/g /etc/yum.conf

if [ ! -f /usr/bin/wget ];then
  yum -y install wget >/dev/null 2>&1
  wget -V >/dev/null 2>&1
  if [ $? -ne 0 ];then echo 'no_wget'&&exit 1;fi
fi

rm -f /etc/yum.repos.d/*.repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum clean all && yum makecache fast

echo $?&&echo '============================================='
yum install -y conntrack ntpdate ntp ipvsadm ipset jq iptables curl sysstat libseccomp wget vim git
echo $?&&echo '============================================='
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
echo $?&&echo '============================================='
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
echo $?&&echo '============================================='
wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
echo $?&&echo '============================================='
wget https://storage.googleapis.com/kubernetes-release/release/v1.14.2/kubernetes-client-linux-amd64.tar.gz
echo $?&&echo '============================================='
wget https://storage.googleapis.com/kubernetes-release/release/v1.14.2/kubernetes-server-linux-amd64.tar.gz
echo $?&&echo '============================================='
wget https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz
echo $?&&echo '============================================='
wget https://github.com/coreos/flannel/releases/download/v0.11.0/flannel-v0.11.0-linux-amd64.tar.gz
echo $?&&echo '============================================='
wget http://nginx.org/download/nginx-1.15.3.tar.gz
echo $?&&echo '============================================='
wget https://download.docker.com/linux/static/stable/x86_64/docker-18.09.6.tgz
echo $?&&echo '============================================='
git clone https://github.com/kubernetes-incubator/metrics-server.git
echo $?&&echo '============================================='
wget https://github.com/docker/compose/releases/download/1.21.2/docker-compose-Linux-x86_64
echo $?&&echo '============================================='
wget  --continue https://storage.googleapis.com/harbor-releases/release-1.5.0/harbor-offline-installer-v1.5.1.tgz
echo $?&&echo '============================================='

echo "pull_docker_image"
docker pull alpine:3.6
echo $?&&echo '============================================='
docker pull docker.elastic.co/kibana/kibana-oss:6.6.1
echo $?&&echo '============================================='
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1
echo $?&&echo '============================================='
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
echo $?&&echo '============================================='
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.3.1
echo $?&&echo '============================================='
docker pull gcr.azk8s.cn/fluentd-elasticsearch/elasticsearch:v6.6.1
echo $?&&echo '============================================='
docker tag gcr.azk8s.cn/fluentd-elasticsearch/elasticsearch:v6.6.1 gcr.io/fluentd-elasticsearch/elasticsearch:v6.6.1
echo $?&&echo '============================================='
docker rmi gcr.azk8s.cn/fluentd-elasticsearch/elasticsearch:v6.6.1
echo $?&&echo '============================================='
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
echo $?&&echo '============================================='
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1 k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
echo $?&&echo '============================================='
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
echo $?&&echo '============================================='
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6
echo $?&&echo '============================================='
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6 k8s.gcr.io/metrics-server-amd64:v0.3.6
echo $?&&echo '============================================='
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server-amd64:v0.3.6
echo $?&&echo '============================================='
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/fluentd-elasticsearch/elasticsearch:v6.6.1
echo $?&&echo '============================================='
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/fluentd-elasticsearch:v2.4.0
echo $?&&echo '============================================='
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/fluentd-elasticsearch:v2.4.0 k8s.gcr.io/fluentd-elasticsearch:v2.4.0
echo $?&&echo '============================================='
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/fluentd-elasticsearch:v2.4.0
echo $?&&echo '============================================='

mkdir docker_image
cd docker_image
for i in $(docker image ls|grep -v 'REPOSITORY'|awk '{print $1":"$2}');do docker save -o $(echo $i|awk -F '/' '{print $NF}').tar $i;done
echo $?&&echo '============================================='
