#!/bin/bash

cat /etc/issue | grep -i ubuntu
if [ $? -ne 0 ];then
	echo "only support for ubuntu/debian"
	exit 1
fi

if [ $# -eq 1 ];then

	cat <<EOF > /etc/network/interfaces.d/eth0.cfg 
	auto eth0
	iface eth0 inet static

	address `echo $1`
	netmask 255.255.255.0
	network 192.168.122.0
	broadcast 192.168.122.255
	gateway 192.168.122.1
	dns-nameservers 192.168.122.1
EOF

	echo "/etc/network/interfaces.d/eth0.cfg updated"
	echo "---------------------------------------------"
	cat /etc/network/interfaces.d/eth0.cfg 
	echo "---------------------------------------------"
	echo "please reboot this vm"
else
	echo "usage: ./set_ip.sh 192.168.122.128"
fi
