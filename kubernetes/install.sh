bash -x copy_ssh_id.sh >>/opt/install_k8s.log 2>&1

bash -x create_ssl.sh >>/opt/install_k8s.log 2>&1

dep_kubectl_tool.sh

dep_etcd.sh

dep_flanneld.sh

kube-apiserver_nginx_proxy.sh
