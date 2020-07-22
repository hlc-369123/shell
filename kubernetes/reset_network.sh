node节点pod无法启动/节点删除网络重置"cni0" already has an IP address different from
node1之前反复添加过,添加之前需要清除下网络

 

# kubectl get pod -n kube-system -o wide|grep tiller
tiller-deploy-86b574cb79-wbncz       0/1     ContainerCreating   0          4m27s   <none>        k8s-node-3   <none>   <none>
复制代码
# kubectl  -n kube-system describe pod tiller-deploy-86b574cb79-wbncz
Name:           tiller-deploy-86b574cb79-wbncz
Namespace:      kube-system
Priority:       0
Node:           k8s-node-3/10.6.76.25
..

  Normal   SandboxChanged          87s (x12 over 112s)  kubelet, k8s-node-3  Pod sandbox changed, it will be killed and re-created.
  Warning  FailedCreatePodSandBox  85s (x4 over 92s)    kubelet, k8s-node-3  (combined from similar events): Failed create pod sandbox: rpc error: code = Unknown desc = failed to set up sandbox container "8216e206b227e96bca8153415fcaf34d26bf969c50fec99de300a955b45cb177" network for pod "tiller-deploy-86b574cb79-wbncz": NetworkPlugin cni failed to set up pod "tiller-deploy-86b574cb79-wbncz_kube-system" network: failed to set bridge addr: "cni0" already has an IP address different from 10.244.3.1/24
[root@k8s-master linux-amd64]# 
复制代码
在Node上执行如下操作：

重置kubernetes服务，重置网络。删除网络配置，link

 

复制代码
kubeadm reset
systemctl stop kubelet
systemctl stop docker
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/*
rm -rf /etc/cni/
ifconfig cni0 down
ifconfig flannel.1 down
ifconfig docker0 down
ip link delete cni0
ip link delete flannel.1
systemctl start docker
systemctl start kubelet
复制代码
获取master的join token

kubeadm token create --print-join-command
重新加入节点

kubeadm join 10.6.76.26:6443 --token iweubu.ebjsywhlaklmgjep     --discovery-token-ca-cert-hash sha256:f03b27e002e77fcec510e057385ce382c02171b7f28d71ac95d8ac0f7c7330b1
master

# kubectl get nodes
NAME         STATUS   ROLES    AGE   VERSION
k8s-master   Ready    master   17h   v1.15.3
k8s-node-1   Ready    node     17h   v1.15.3
k8s-node-2   Ready    node     17h   v1.15.3
k8s-node-3   Ready    node     17h   v1.15.3
 
