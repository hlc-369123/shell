#!/bin/bash

# 修改hostsname.txt environment.sh (ip/主机名/网卡名/密码)

sed -i s/172.16.68.11/x.x.x.x/ hostsname.txt

bash -x copy_ssh_id.sh >>/opt/install_k8s.log 2>&1

cd bin

bash -x create_ssl.sh >>/opt/install_k8s.log 2>&1

bash -x dep_kubectl_tool.sh >>/opt/install_k8s.log 2>&1

# 修改etcd ip，ip不要写错，不然etcd无法启动
bash -x dep_etcd.sh >>/opt/install_k8s.log 2>&1

bash -x dep_flanneld.sh >>/opt/install_k8s.log 2>&1

# 修改etcd ip，ip不要写错
bash -x kube-apiserver_nginx_proxy.sh >>/opt/install_k8s.log 2>&1

bash -x dep_master.sh >>/opt/install_k8s.log 2>&1

# 修改ip，ip不要写错
bash -x kube-apiserver.sh >>/opt/install_k8s.log 2>&1

# 修改ip，ip不要写错
bash -x kube-controller-manager.sh >>/opt/install_k8s.log 2>&1

# 修改ip，ip不要写错
bash -x kube-scheduler.sh >>/opt/install_k8s.log 2>&1

bash -x dep_docker.sh >>/opt/install_k8s.log 2>&1

bash -x kubelet.sh >>/opt/install_k8s.log 2>&1

bash -x kube-proxy.sh >>/opt/install_k8s.log 2>&1

bash -x dns.sh >> /opt/install_k8s.log 2>&1

bash -x dashboard.sh >> /opt/install_k8s.log 2>&1

bash -x metrics-server.sh >> /opt/install_k8s.log 2>&1

bash -x EFK.sh >> /opt/install_k8s.log 2>&1
