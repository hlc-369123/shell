#!/bin/bash

ip addr del 10.255.20.121/24 dev ens224 && brctl addbr br0 && ip link set br0 up &&  brctl addif br0 ens224 && ip addr add 10.255.20.121/24 dev br0 
#ip route add defaule via 10.255.20.254 dev  br0
