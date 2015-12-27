#QuickStart: Create Swarm Cluster with vm_nat.sh


## 1.create vm

	./vm_nat.sh create ubuntu14.04 swarm 192.168.122.128
	./vm_nat.sh create ubuntu14.04 node1 192.168.122.129
	./vm_nat.sh create ubuntu14.04 node2 192.168.122.130


## 2.create swarm cluster

	$ ./vm_nat.sh exec swarm "docker run --rm swarm create"
	59cb545ece12c6e15ce3fe6d74755aac # <= token for cluster


## 3.start swarm manager

	$ ./vm_nat.sh exec swarm "docker run --restart=always -t -p 23750:2375 -t swarm manage token://59cb545ece12c6e15ce3fe6d74755aac"


## 4.start swarm node

	$ ./vm_nat.sh exec node1 "docker run -d --restart=always swarm join --addr=192.168.122.129:2375 token://59cb545ece12c6e15ce3fe6d74755aac"
	$ ./vm_nat.sh exec node2 "docker run -d --restart=always swarm join --addr=192.168.122.130:2375 token://59cb545ece12c6e15ce3fe6d74755aac"


## 5.list node in swarm cluster

	$ curl https://discovery.hub.docker.com/v1/clusters/59cb545ece12c6e15ce3fe6d74755aac
	or
	$ docker -H 192.168.122.128:23750 info
	or
	$ docker run --rm swarm list token://59cb545ece12c6e15ce3fe6d74755aac


## 6.set env DOCKER_HOST in docker client

	$ export DOCKER_HOST=192.168.122.128:23750


## 7.pull image in cluster

	$ docker pull nginx
	Using default tag: latest
	node1: Pulling nginx:latest... : downloaded 
	node2: Pulling nginx:latest... : downloaded 


## 8.run container in cluster

	$ docker run -d --name nginx1 -p 8888:80 nginx
	$ docker run -d --name nginx2 -p 8888:80 nginx


## 9.list container in cluster

	$ docker ps
	CONTAINER ID  IMAGE  COMMAND                 CREATED                 STATUS                 PORTS                                  NAMES
	8a256b47fe3c  nginx  "nginx -g 'daemon off"  Less than a second ago  Up Less than a second  443/tcp, 192.168.122.129:8888->80/tcp  node1/nginx2
	c5ce7f82ed73  nginx  "nginx -g 'daemon off"  Less than a second ago  Up Less than a second  443/tcp, 192.168.122.130:8888->80/tcp  node2/nginx1
