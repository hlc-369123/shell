#!/bin/bash

cat>/etc/hosts<<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

grep 'hostlist' hostsname.txt|awk -F ':' '{print $2}' | while read host ip pwd; do
  scp /etc/hosts $ip:/etc/
  ssh -nq $ip "rm -rf /root/.ssh"
done

yum -y remove sshpass >/dev/null 2>&1
rm -f /usr/bin/sshpass
rm -rf /root/.ssh/
