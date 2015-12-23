#!/bin/bash

echo "======= run in vm ========"
if [ -f /tmp/run.log ];then
	cat /tmp/run.log
fi

echo "== init =================="

echo "read from config"
HOST_IP=$(grep HOST_IP config | cut -d"=" -f2)

cat /etc/issue | grep -i -E "(centos|fedora)"
if [ $? -eq 0 ];then
	echo "init for centos|fedora"
	
	echo "> change yum repo"
	yum install -y wget 
	wget http://mirrors.163.com/.help/CentOS6-Base-163.repo -O /etc/yum.repos.d/CentOS6-Base-163.repo
	
	echo "> install docker"
	wget -qO- https://get.docker.com/ | sh

	echo "> config docker"
	grep http_proxy /etc/sysconfig/docker
	if [ $? -eq 0 ];then
		sed -r -i "s@.*http_proxy=.*@http_proxy='http://${HOST_IP}:8118/'@" /etc/sysconfig/docker
	else
		echo "http_proxy='http://${HOST_IP}:8118/" >> /etc/sysconfig/docker	
	fi
	sed -r -i "s@.*other_args=.*@other_args='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors'@" /etc/sysconfig/docker

else
	cat /etc/issue | grep -i ubuntu
	if [ $? -eq 0 ];then
		echo "init for ubuntu"

		sleep 3
		echo "> change apt source"
		mv /etc/apt/sources.list /etc/apt/sources.list.bak
		wget http://mirrors.163.com/.help/sources.list.trusty -O /etc/apt/sources.list	

		echo "> disable downloading translations"
		echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations

		echo "> install docker"
		wget -qO- https://get.docker.com/ | sh

		echo "> config docker"
		sed -r -i "s@.*export http_proxy=.*@export http_proxy='http://${HOST_IP}:8118/'@" /etc/default/docker
		sed -r -i "s@.*DOCKER_OPTS=.*@DOCKER_OPTS='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors'@" /etc/default/docker

	else
		echo "unknown os distro"
		cat /etc/issue
		exit 1
	fi
fi

docker info
if [ $? -eq 0 ];then
	echo "> restart docker daemon"
	service docker restart

	echo "> pull busybox image"
	sleep 2
	docker pull busybox
	docker pull swarm

	echo "> test busybox"
	docker run -i --rm busybox uname -a
else
	echo "docker daemon isn't running:("
fi

echo "> show ip info"
ifconfig eth0 | head -n2

echo "== done =================="
