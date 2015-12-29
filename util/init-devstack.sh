#!/bin/bash

echo "======= run in vm ========"
if [ -f /tmp/run.log ];then
	cat /tmp/run.log
fi

echo "== init =================="

echo "read from config"
HOST_IP=$(grep HOST_IP config | cut -d"=" -f2)

ping -c 2 114.114.115.115
cnt=0
while [ $? -ne 0 ]
do
	if [ $cnt -gt 10 ];then
		echo "dns error!"
		exit 1
	fi
	ping -c 2 114.114.115.115
	cnt=$((cnt + 1))
done

cat /etc/issue | grep -i -E "(centos|fedora)" || cat /etc/os-release | grep -i -E "(centos|fedora)"
if [ $? -eq 0 ];then
	echo "init for centos|fedora"
	# install devstack

else
	cat /etc/issue | grep -i ubuntu
	if [ $? -eq 0 ];then
		echo "init for ubuntu"
		# install devstack

	else
		echo "unknown os distro"
		echo "----------------------"
		cat /etc/issue
		echo "----------------------"
		cat /etc/os-release
		echo "----------------------"
		exit 1
	fi
fi

echo "> show ip info"
ifconfig eth0 | head -n2

echo "== done =================="
