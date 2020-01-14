#!/bin/bash

sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' /etc/ssh/ssh_config
if [ ! -f sshpass ];then
  sshpass -V >/dev/null 2>&1
  if [ $? -ne 0 ];then echo 'no_sshpass'&&exit 1;fi
else
  if [ ! -f /usr/bin/sshpass ];then cp ./sshpass /usr/bin/sshpass;fi
  if [ ! -x /usr/bin/sshpass ];then chmod +x /usr/bin/sshpass;fi
fi

grep '^hostlist' hostsname.txt|awk -F ':' '{print $2}' | while read host ip pwd; do
  /usr/bin/sshpass -p $pwd ssh-copy-id -f $ip 2>/dev/null
  /usr/bin/sshpass -p $pwd ssh -nq $ip "hostnamectl set-hostname $host"
  /usr/bin/sshpass -p $pwd ssh -nq $ip "echo -e 'y\n' | ssh-keygen -q -f ~/.ssh/id_rsa -t rsa -N ''"
  echo "===== Copy id_rsa.pub of $ip ====="
  /usr/bin/sshpass -p $pwd scp $ip:/root/.ssh/id_rsa.pub ./$host-id_rsa.pub
  cat ./$host-id_rsa.pub >> /root/.ssh/authorized_keys
  grep "$ip" /etc/hosts
  if [ $? -ne 0 ];then echo $ip $host >> /etc/hosts;fi
done

grep '^hostlist' hostsname.txt|awk -F ':' '{print $2}' | while read host ip pwd; do
  rm -f ./$host-id_rsa.pub
  echo "===== Copy authorized_keys to $ip ====="
  /usr/bin/sshpass -p $pwd scp /root/.ssh/authorized_keys $ip:/root/.ssh/
  scp /etc/hosts $ip:/etc/
  scp /etc/ssh/ssh_config $ip:/etc/ssh/ssh_config
  ssh -nq $ip "systemctl restart sshd"
  scp -r packages k8s_init.sh $ip:/opt/
  ssh -nq $ip "cd /opt && bash /opt/k8s_init.sh && rm -rf packages k8s_init.sh"
done
