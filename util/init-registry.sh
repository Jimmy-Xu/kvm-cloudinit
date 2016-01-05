#!/bin/bash

echo "======= run in vm ========"
if [ -f /tmp/run.log ];then
	cat /tmp/run.log
fi

echo "== init =================="

echo "> read from config"
HOST_IP=$(grep HOST_IP config | cut -d"=" -f2)

ping -c 2 114.114.115.115
cnt=0
while [ $? -ne 0 ]
do
	if [ $cnt -gt 10 ];then
		echo "> dns error!"
		exit 1
	fi
	ping -c 2 114.114.115.115
	cnt=$((cnt + 1))
done

#check os_type
cat /etc/issue | grep -i -E "(centos|fedora)" || cat /etc/os-release | grep -i -E "(centos|fedora)"
if [ $? -eq 0 ];then
	_TYPE="centos"
else
	cat /etc/issue | grep -i ubuntu
	if [ $? -eq 0 ];then
		_TYPE="ubuntu"
	else
		echo "> unknown os distro"
		echo "----------------------"
		cat /etc/issue
		echo "----------------------"
		cat /etc/os-release
		echo "----------------------"
		exit 1
	fi
fi

	
if [ "${_TYPE}" == "centos" ];then
	echo "> init for centos|fedora"
	which docker
	if [ $? -ne 0 ];then
		echo "> need install docker"
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
			echo "> config docker service for systemd: ${DOCKER_SVR}"

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

			echo "> daemon-reload for systemd..."
			systemctl daemon-reload
			echo "> enable docker autostart..."
			systemctl enable docker
		fi

		echo "> restart docker daemon"
		service docker restart
	fi

elif [ "${_TYPE}" == "ubuntu" ];then
	echo "init for ubuntu"
	which docker
	if [ $? -ne 0 ];then
		echo "> need install docker"

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
		sed -r -i "s@.*DOCKER_OPTS=.*@DOCKER_OPTS='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry registry.hyper.sh -api-enable-cors'@" ${DOCKER_CFG}

		echo "> restart docker daemon"
		service docker restart
	fi

	echo "> install distribution..."

	echo "> install apache"
	apt-get update
	apt-get install -y apache2-utils
	
	echo "> install nginx"
	nginx -v
	if [ $? -ne 0 ];then
		grep "deb .*nginx" /etc/apt/sources.list && echo "nginx in apt source already" || echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list
		grep "deb-src .*nginx" /etc/apt/sources.list && echo "nginx in apt source already" || echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list
		wget http://nginx.org/keys/nginx_signing.key -O /etc/apt/nginx_signing.key
		apt-key add /etc/apt/nginx_signing.key
		apt-get update
		DEBIAN_FRONTEND=noninteractive

		apt-get install -y -o DPkg::Options="--force-confold" nginx
		nginx -v
	fi


	if [ ! -f /etc/nginx/ssl/nginx.cert ];then
		echo "> generate new ssl cert for nginx"
		mkdir ~/certs
		cd ~/certs
		openssl genrsa -out dockerCA.key 2048
		openssl req -x509 -new -nodes -key dockerCA.key -days 10000 -out dockerCA.crt -subj "/C=CN/ST=BJ/L=BJ/O=hyper/OU=hyper/CN=*.hyper.sh/emailAddress=xjimmyshcn@gmail.com"
		openssl genrsa -out nginx.key 2048 
		openssl req -new -key nginx.key -out nginx.csr -subj "/C=CN/ST=BJ/L=BJ/O=hyper/OU=hyper/CN=*.hyper.sh/emailAddress=xjimmyshcn@gmail.com"
		openssl x509 -req -in nginx.csr -CA dockerCA.crt -CAkey dockerCA.key -CAcreateserial -out nginx.crt -days 10000
		mkdir -p /etc/nginx/ssl/
		cp ~/certs/{nginx.key,nginx.crt} /etc/nginx/ssl/
	fi


	echo "> create user and group for www"
	groupadd www -g 58
	useradd -u 58 -g www www

	echo "> create login user for docker client"
	USER="test"
	PASSWORD="aaa123aa"
	if [ ! -f /etc/nginx/.htpasswd ];then
		htpasswd -cb /etc/nginx/.htpasswd ${USER} ${PASSWORD}
	else
		htpasswd -b /etc/nginx/.htpasswd ${USER} ${PASSWORD}
	fi

	service nginx start

	if [ ! -f /etc/ssl/certs/dockerCA.pem  ];then
		echo "> start make root cert as legal certificate..."
		mkdir -p /usr/local/share/ca-certificates/docker-dev-cert
		cp ~/certs/dockerCA.crt /usr/local/share/ca-certificates/docker-dev-cert
		update-ca-certificates
	fi
	if [ -f /etc/ssl/certs/dockerCA.pem ];then
		echo "> make root cert as legal certificate OK"
	else
		echo "> make root cert as legal certificate Failed"
		exit 1
	fi
fi


echo "start docker..."
service docker start

docker info
if [ $? -eq 0 ];then

	docker images busybox | grep busybox
	if [ $? -ne 0 ];then
		echo "> pull busybox image"
		sleep 2
		docker pull busybox
	else
		echo "> busybox image already pulled"
	fi
	echo "> test busybox"
	docker run -i --rm busybox uname -a
else
	echo "> docker daemon isn't running:("
fi

echo "> check docker distribution..."
if [ ! -d ~/distribution ];then
	cd ~
	git clone https://github.com/docker/distribution.git
	cd ~/distribution
else
	cd ~/distribution
	git checkout -- Dockerfile
	git pull	
fi

echo "> patch distribution/Dockerfile"
sed -i "/FROM golang:1.5.2/ a RUN wget http:\/\/mirrors.163.com\/.help\/sources.list.trusty -O \/etc\/apt\/sources.list\nRUN echo \'Acquire::Languages \"none\";\' > \/etc\/apt\/apt.conf.d\/99translations" Dockerfile
sed -i "s/apt-get install -y/& --allow-unauthenticated=true/" Dockerfile 

echo "> pull golang:1.5.2"
docker pull golang:1.5.2

echo "> build docker distribution"
docker build --rm -t registry:latest .
if [ $? -eq 0 ];then
	echo "> start registry 2.0"
	docker run -d -p 127.0.0.1:5000:5000 --restart=always --name registry -v /root/config.yml:/etc/docker/registry/config.yml  registry:latest
	echo "> verify registry"
	curl -i -k https://test:aaa123aa@registry.hyper.sh
fi


echo "> show ip info"
ifconfig eth0 | head -n2


echo "== done =================="
