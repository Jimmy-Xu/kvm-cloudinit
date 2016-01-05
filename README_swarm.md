#QuickStart: Create Swarm Cluster with vm_nat_swarm.sh


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
	## way1 (create three new VM)
	$ ./vm_nat.sh swarm create ubuntu14.04 swarm 192.168.122.128
	$ ./vm_nat.sh swarm create ubuntu14.04 node1 192.168.122.129
	$ ./vm_nat.sh swarm create ubuntu14.04 node2 192.168.122.130
	$ ./vm_nat.sh swarm create ubuntu14.04 node3 192.168.122.131

	## way2 (create one VM, clone another two VM)
	$ ./vm_nat.sh swarm create ubuntu14.04 swarm 192.168.122.128
	$ ./vm_nat.sh swarm stop swarm
	$ ./vm_nat.sh swarm clone swarm node1
	$ ./vm_nat.sh swarm clone swarm node2
	$ ./vm_nat.sh swarm clone swarm node3

	$ ./vm_nat.sh swarm start swarm
	$ ./vm_nat.sh swarm start node1 192.168.122.129
	$ ./vm_nat.sh swarm start node2 192.168.122.130
	$ ./vm_nat.sh swarm start node3 192.168.122.131

	### remove /etc/docker/key.json after clone VM (https://github.com/docker/swarm/issues/362)
	$ ./vm_nat.sh swarm exec node1 "mv /etc/docker/key.json /etc/docker/key.json.orig; service docker restart; sleep 1; cat /etc/docker/key.json"
	$ ./vm_nat.sh swarm exec node2 "mv /etc/docker/key.json /etc/docker/key.json.orig; service docker restart; sleep 1; cat /etc/docker/key.json"
	$ ./vm_nat.sh swarm exec node3 "mv /etc/docker/key.json /etc/docker/key.json.orig; service docker restart; sleep 1; cat /etc/docker/key.json"

	# list vm
	$./vm_nat.sh swarm list
	VMNAME	PID		MAC_ADDR			CURRENT_IP		IP_TYPE	CONFIG_IP		BACKING_IMAGE
	node1   25643	52:54:00:98:2a:b4	192.168.122.129	static	192.168.122.129	ubuntu14.04.img
	node2   25717	52:54:00:a0:93:ce	192.168.122.130	static	192.168.122.130	ubuntu14.04.img
	node3   7120	52:54:00:2e:d2:3d	192.168.122.131	static	192.168.122.131	ubuntu14.04.img
	swarm   25356	52:54:00:08:c2:b8	192.168.122.128	static	192.168.122.128	ubuntu14.04.img


## 3.create a swarm cluster

	$ ./vm_nat.sh swarm exec swarm "docker run --rm swarm create"
	87de387aa0f301d40f47f744a8616243 # <= token for cluster


## 4.start swarm manager

	$ ./vm_nat.sh swarm exec swarm "docker run --restart=always -t -p 23750:2375 -t swarm manage token://87de387aa0f301d40f47f744a8616243"


## 5.start swarm node

	# node1 join to swarm cluster
	$ ./vm_nat.sh swarm exec node1 "docker run -d --restart=always swarm join --addr=192.168.122.129:2375 token://87de387aa0f301d40f47f744a8616243"
	
	# node2 join to swarm cluster
	$ ./vm_nat.sh swarm exec node2 "docker run -d --restart=always swarm join --addr=192.168.122.130:2375 token://87de387aa0f301d40f47f744a8616243"

	# node3 join to swarm cluster
	$ ./vm_nat.sh swarm exec node3 "docker run -d --restart=always swarm join --addr=192.168.122.131:2375 token://87de387aa0f301d40f47f744a8616243"


## 6.list node in swarm cluster

	$ curl https://discovery.hub.docker.com/v1/clusters/87de387aa0f301d40f47f744a8616243
	or
	$ docker -H 192.168.122.128:23750 info
	or
	$ docker run --rm swarm list token://87de387aa0f301d40f47f744a8616243


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
