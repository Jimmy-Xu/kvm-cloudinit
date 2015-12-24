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
	
	DOCKER_CFG=/etc/sysconfig/docker
	DOCKER_SVR=/lib/systemd/system/docker.service

	echo "> change yum repo"
	yum install -y wget
	if [ $? -ne 0 ];then
		curl http://mirrors.163.com/.help/CentOS7-Base-163.repo > /etc/yum.repos.d/CentOS7-Base-163.repo
		curl http://mirrors.163.com/.help/CentOS6-Base-163.repo > /etc/yum.repos.d/CentOS6-Base-163.repo
		yum install -y wget
	fi
	wget http://mirrors.163.com/.help/CentOS6-Base-163.repo -O /etc/yum.repos.d/CentOS6-Base-163.repo
	wget http://mirrors.163.com/.help/CentOS7-Base-163.repo -O /etc/yum.repos.d/CentOS7-Base-163.repo

	echo "> install docker"
	wget -qO- https://get.docker.com/ | sh

	echo "> config docker: ${DOCKER_CFG}"
	grep http_proxy ${DOCKER_CFG}
	if [ $? -eq 0 ];then
		sed -r -i "s@.*http_proxy=.*@http_proxy='http://${HOST_IP}:8118/'@" ${DOCKER_CFG}
	else
		echo "http_proxy='http://${HOST_IP}:8118/'" >> ${DOCKER_CFG}
	fi
	grep other_args ${DOCKER_CFG}
	if [ $? -eq 0 ];then
		sed -r -i "s@.*other_args=.*@other_args='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors'@" ${DOCKER_CFG}
	else
		echo "other_args='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors" >> ${DOCKER_CFG}
	fi

	if [ -f ${DOCKER_SVR} ];then
		#for centos7
		echo "config docker service for systemd: ${DOCKER_SVR}"

		grep EnvironmentFile ${DOCKER_SVR}
		if [ $? -eq 0 ];then
			sed -r -i "s@EnvironmentFile=.*@EnvironmentFile=-${DOCKER_CFG}@" ${DOCKER_SVR}
		else
			sed -i "/\[Service\]/ a EnvironmentFile=-${DOCKER_CFG}" ${DOCKER_SVR}
		fi

		sed -r -i "s@ExecStart=.*@ExecStart=/usr/bin/docker daemon \$other_args -H fd://@" ${DOCKER_SVR}

		echo "-- ${DOCKER_CFG} -----------"
		cat ${DOCKER_CFG}
		echo "----------------------------"

		echo "daemon-reload for systemd..."
		systemctl daemon-reload
	fi

	echo "> restart docker daemon"
	service docker restart

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

		DOCKER_CFG=/etc/default/docker
		echo "> config docker: ${DOCKER_CFG}"
		sed -r -i "s@.*export http_proxy=.*@export http_proxy='http://${HOST_IP}:8118/'@" ${DOCKER_CFG}
		sed -r -i "s@.*DOCKER_OPTS=.*@DOCKER_OPTS='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors'@" ${DOCKER_CFG}

		echo "> restart docker daemon"
		service docker restart

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

docker info
if [ $? -eq 0 ];then

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
