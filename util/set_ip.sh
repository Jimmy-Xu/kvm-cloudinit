#!/bin/bash
# set ip and hostname

echo "read from config"
NETWORK_PREFIX=$(grep NETWORK_PREFIX config | cut -d"=" -f2)

if [ $# -eq 2 ];then

	NEW_HOSTNAME=$1
	NEW_IP=$2

	echo "NEW_HOSTNAME: $NEW_HOSTNAME"
	echo "NEW_IP      : ${NEW_IP}"

	echo "> change hostname from $(hostname) to ${NEW_HOSTNAME}..."
	sed -i "/127.0.0.1 $(hostname)$/d" /etc/hosts
	echo 127.0.0.1 $NEW_HOSTNAME >> /etc/hosts
	hostname $NEW_HOSTNAME

	echo "> change /etc/hostname..."
	echo $NEW_HOSTNAME > /etc/hostname

	echo "> show /etc/hosts ..."
	cat /etc/hosts

	echo "> show /etc/hostname ..."
	cat /etc/hostname


	echo ">check os..."
	cat /etc/issue | grep -i ubuntu
	if [ $? -eq 0 ];then
		echo "> set static ip for ubuntu/debian"
		cat <<EOF > /etc/network/interfaces.d/eth0.cfg 
auto eth0
iface eth0 inet static

address `echo $NEW_IP`
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

	else
		cat /etc/issue | grep -i -E "(centos|fedora)" || cat /etc/os-release | grep -i -E "(centos|fedora)"
		if [ $? -eq 0 ];then
			echo "> set static ip for centos|fedora"
			cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
IPV6INIT=no
ONBOOT=yes
TYPE=Ethernet
IPADDR=`echo $NEW_IP`
NETWORK=`echo ${NETWORK_PREFIX}.0`
NETMASK=255.255.255.0
NM_CONTROLLED=no
#UUID=3f92192e-7765-4488-9746-41d7cc477dd0
EOF
		echo "/etc/sysconfig/network-scripts/ifcfg-eth0 updated"
		echo "---------------------------------------------"
		cat /etc/sysconfig/network-scripts/ifcfg-eth0 
		echo "---------------------------------------------"
		else
			echo "only support ubuntu14.04, centos6, fedora22, fedora23"
			exit 1
		fi
	fi

	echo "please reboot this vm"
else
	echo "usage: ./set_ip.sh <new_hostname> <new_ip>"
	echo "eg: ./set_ip.sh node1 ${NETWORK_PREFIX}.128"
fi
