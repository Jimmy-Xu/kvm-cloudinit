#!/bin/bash

cat /etc/issue | grep -i ubuntu
if [ $? -ne 0 ];then
	echo "only support for ubuntu/debian"
	exit 1
fi

NETWORK_PREFIX="192.168.122"
#NETWORK_PREFIX="192.168.1"

if [ $# -eq 1 ];then

	cat <<EOF > /etc/network/interfaces.d/eth0.cfg 
	auto eth0
	iface eth0 inet static

	address `echo $1`
	netmask 255.255.255.0
	network `echo ${NETWORK_PREFIX}`.0
	broadcast `echo ${NETWORK_PREFIX}`.255
	gateway `echo ${NETWORK_PREFIX}`.1
	dns-nameservers `echo ${NETWORK_PREFIX}`.1
EOF

	echo "/etc/network/interfaces.d/eth0.cfg updated"
	echo "---------------------------------------------"
	cat /etc/network/interfaces.d/eth0.cfg 
	echo "---------------------------------------------"
	echo "please reboot this vm"
else
	echo "usage: ./set_ip.sh ${NETWORK_PREFIX}.128"
fi
