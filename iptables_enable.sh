#!/bin/bash
set -e -o pipefail

yum -y install iptables-services
systemctl start iptables
systemctl enable iptables
iptables -I INPUT -p tcp -m tcp --dport 8051 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 8052 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 8053 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 8056 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 8058 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 5432 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 5433 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 8061 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 9090 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 6789 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 6800:7300 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 3260 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 3333 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 3334 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 2049 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 4379 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 139 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 445 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 111 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 11995 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 11996 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 11997 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 11998 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 11999 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7480 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 8060 -j ACCEPT 
iptables -I INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 12000:22000 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 111 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 21 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 875 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7480 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7481 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7470 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 7471 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 8081 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 9210 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 9310 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 9200:9300 -j ACCEPT
iptables -I INPUT -p tcp -m multiport --dport 2379,2380 -j DROP
iptables -I INPUT -p tcp -m iprange --src-range 172.31.32.53-172.31.32.64 -m multiport --dports 2379,2380 -j ACCEPT
iptables -I INPUT -p tcp -m tcp -s 127.0.0.1 -m multiport --dports 2379,2380 -j ACCEPT
iptables -L -n
service iptables save
