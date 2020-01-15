bash -x copy_ssh_id.sh >>/opt/install_k8s.log 2>&1

check_env.sh

create_ssl.sh

dep_kubectl_tool.sh

dep_etcd.sh

dep_flanneld.sh

kube-apiserver_nginx_proxy.sh
