#QuickStart: Create Swarm Cluster with vm_nat.sh


## 1.prepare

	# install kvm, libvirt and cloud-localds
	$ make
	$ make ubuntu14.04


## 2.create vm

	+-------------------------------------host--------------------------------------+
	|                                                                               |
	|                            +---------vm----------+                            |
	|                            |                     |                            |
	|                            |  +----docker-----+  |                            |
	|                            |  |               |  |                            |
	|                            |  |  +---------+  |  |                            |
	|                            |  |  | manager |  |  |                            |
	|                            |  |  +---------+  |  |                            |
	|                            |  |               |  |                            |
	|                            |  +---------------+  |                            |
	|                            |     ubuntu14.04     |                            |
	|                            +---192.168.122.128---+                            |
	|                                                                               |
	|   +---------vm----------+  +---------vm----------+  +---------vm----------+   |
	|   |                     |  |                     |  |                     |   |
	|   |  +----docker-----+  |  |  +----docker-----+  |  |  +----docker-----+  |   |
	|   |  |               |  |  |  |               |  |  |  |               |  |   |
	|   |  |  +---------+  |  |  |  |  +---------+  |  |  |  |  +---------+  |  |   |
	|   |  |  |  agent  |  |  |  |  |  |  agent  |  |  |  |  |  |  agent  |  |  |   |
	|   |  |  +---------+  |  |  |  |  +---------+  |  |  |  |  +---------+  |  |   |
	|   |  |               |  |  |  |               |  |  |  |               |  |   |
	|   |  +---------------+  |  |  +---------------+  |  |  +---------------+  |   |
	|   |     ubuntu14.04     |  |     ubuntu14.04     |  |     ubuntu14.04     |   |
	|   +---192.168.122.129---+  +---192.168.122.130---+  +---192.168.122.131---+   |
	|                                                                               |
	+-------------------------------------------------------------------------------+

	#create three vm( swarm: swarm manager, node1&node2: swarm node )
	$ ./vm_nat.sh create ubuntu14.04 swarm 192.168.122.128
	$ ./vm_nat.sh create ubuntu14.04 node1 192.168.122.129
	$ ./vm_nat.sh create ubuntu14.04 node2 192.168.122.130

	# list vm
	$./vm_nat.sh list
	vmName	PID		mac_addr			guest_ip		backing_image
	node1	24982	52:54:00:bd:ca:11	192.168.122.129	ubuntu14.04.img
	node2	25105	52:54:00:0a:92:12	192.168.122.130	ubuntu14.04.img
	swarm	24175	52:54:00:c4:6c:63	192.168.122.128	ubuntu14.04.img


## 3.create a swarm cluster

	$ ./vm_nat.sh exec swarm "docker run --rm swarm create"
	59cb545ece12c6e15ce3fe6d74755aac # <= token for cluster


## 4.start swarm manager

	$ ./vm_nat.sh exec swarm "docker run --restart=always -t -p 23750:2375 -t swarm manage token://59cb545ece12c6e15ce3fe6d74755aac"


## 5.start swarm node

	# node1 join to swarm cluster
	$ ./vm_nat.sh exec node1 "docker run -d --restart=always swarm join --addr=192.168.122.129:2375 token://59cb545ece12c6e15ce3fe6d74755aac"
	
	# node2 join to swarm cluster
	$ ./vm_nat.sh exec node2 "docker run -d --restart=always swarm join --addr=192.168.122.130:2375 token://59cb545ece12c6e15ce3fe6d74755aac"


## 6.list node in swarm cluster

	$ curl https://discovery.hub.docker.com/v1/clusters/59cb545ece12c6e15ce3fe6d74755aac
	or
	$ docker -H 192.168.122.128:23750 info
	or
	$ docker run --rm swarm list token://59cb545ece12c6e15ce3fe6d74755aac


## 7.set DOCKER_HOST in docker client

	$ export DOCKER_HOST=192.168.122.128:23750


## 8.pull image in cluster

	$ docker pull nginx
	Using default tag: latest
	node1: Pulling nginx:latest... : downloaded 
	node2: Pulling nginx:latest... : downloaded 


## 9.run container in cluster

	$ docker run -d --name nginx1 -p 8888:80 nginx
	$ docker run -d --name nginx2 -p 8888:80 nginx


## 10.list container in cluster


	$ docker ps
	CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS         PORTS                                   NAMES
	8a256b47fe3c   nginx   "nginx -g 'daemon off"   4 minutes ago   Up 4 minutes   443/tcp, 192.168.122.129:8888->80/tcp   node1/nginx2
	c5ce7f82ed73   nginx   "nginx -g 'daemon off"   4 minutes ago   Up 4 minutes   443/tcp, 192.168.122.130:8888->80/tcp   node2/nginx1
