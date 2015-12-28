#Create a docker swarm cluster 

	- Host OS
		- Debian(8) / Ubuntu(14.04)
		- qemu: v2.0+
	- Three kvm VM
		- cloud image: http://cloud-images.ubuntu.com/releases/14.04/release-20151217/ubuntu-14.04-server-cloudimg-amd64-disk1.img
		- install docker (each vm)
		- pull swarm image (each vm)
	- Three docker container
		- swarm: cluster manager (ubuntu14.04, docker 1.9.1)
		- node1: docker host     (ubuntu14.04, docker 1.9.1)
		- node2: docker host     (ubuntu14.04, docker 1.9.1)
		- node3: docker host     (centos7, docker 1.9.1)

>docker daemon and docker client should be the same version


#1 Prepare VM

	# config network and bridge
	### for Bridge network
	BR=br0
	NETWORK_PREFIX=192.168.1
	HOST_IP=192.168.1.141 # <= host ip address

	# create three VMs
	$ ./vm_nat.sh create ubuntu14.04 swarm 192.168.1.128
	$ ./vm_nat.sh create ubuntu14.04 node1 192.168.1.129
	$ ./vm_nat.sh create ubuntu14.04 node2 192.168.1.130


	# show vm info
	$./vm_nat.sh list
	vmName	PID		mac_addr			guest_ip		backing_image
	node1	3299	52:54:00:af:e7:7b	192.168.1.129	ubuntu14.04.img
	node2	3510	52:54:00:76:a7:69	192.168.1.130	ubuntu14.04.img
	swarm	3041	52:54:00:d5:a9:12	192.168.1.128	ubuntu14.04.img



#2 Configure Swarm Cluster


###2.1 [swarm]: create cluster

	# run on host
	$ ./vm_nat.sh exec swarm "docker run --rm swarm create"
	----------------------------------
	BR            : br0
	NETWORK_PREFIX: 192.168.1
	-----------------------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.1.128 "bash -c 'docker run --rm swarm create'"
	-----------------------------------------------------------------------------------------------------------------------------------------
	08794256f34728021d1947832ae8bd88
	-----------------------------------------------------------------------------------------------------------------------------------------

	or

	# ssh to swarm
	$ ./vm_nat.sh ssh swarm
	# run on swarm
	root@swarm:~# docker run --rm swarm create
	08794256f34728021d1947832ae8bd88 # <- this is <cluster_id>


###2.2 [node1]: join to cluster (on each of your nodes, start the swarm agent)
	
	# ssh to node1
	$ ./vm_nat.sh ssh node1

	# run on node1: (on each of your nodes, start the swarm agent)
	root@node1:~# docker run -d --restart=always swarm join --addr=192.168.1.129:2375 token://08794256f34728021d1947832ae8bd88
	d1af74a346511f1b455df62d96ff7a0d491cb63dc772746742ca81af585b3363

	root@node1:~# docker ps
	CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS         PORTS      NAMES
	d1af74a34651   swarm   "/swarm join --addr=1"   2 seconds ago   Up 2 seconds   2375/tcp   condescending_liskov


###2.3 [node2]: join to cluster (on each of your nodes, start the swarm agent)

	# ssh to node2
	$ ./vm_nat.sh ssh node2
	
	# run on node2: (on each of your nodes, start the swarm agent)
	root@node2:~# docker run -d --restart=always swarm join --addr=192.168.1.130:2375 token://08794256f34728021d1947832ae8bd88
	071b5769a4574169c7bd2a151a0f3645a3c1b8488a4ec13c8ffdd42dc02c9008

	root@node2:~# docker ps
	CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS      NAMES
	071b5769a457   swarm   "/swarm join --addr=1"   13 seconds ago   Up 12 seconds   2375/tcp   tender_hopper



#3 Start the manager 

###3.1 [swarm]: start service

	# ssh to swarm
	$ ./vm_nat.sh ssh swarm

	# check node1 and node2 on swarm(should be ok)
	root@swarm:~# docker -H 192.168.1.129:2375 images
	root@swarm:~# docker -H 192.168.1.130:2375 images

	# start the manager on any machine or your laptop
	root@swarm:~# docker run --restart=always -p 23750:2375 -t swarm manage token://08794256f34728021d1947832ae8bd88
	INFO[0000] Listening for HTTP                            addr=:2375 proto=tcp
	INFO[0001] Registered Engine node1 at 192.168.1.129:2375 
	INFO[0001] Registered Engine node2 at 192.168.1.130:2375 

	# list nodes in your cluster( run on any machine )
	docker run --rm swarm list token://08794256f34728021d1947832ae8bd88 
	192.168.1.130:2375
	192.168.1.129:2375

	# check swarm service
	$ ./vm_nat.sh exec swarm "netstat -tnopl"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.1.128 "bash -c 'netstat -tnopl'"
	---------------------------------------------------------------------------------------------------------------------------
	Active Internet connections (only servers)
	Proto Recv-Q Send-Q Local Address     Foreign Address  State     PID/Program name Timer
	tcp6       0      0 :::23750          :::*             LISTEN    12359/docker-proxy off (0.00/0/0)
	tcp6       0      0 :::2375           :::*             LISTEN    12027/docker     off (0.00/0/0)
	---------------------------------------------------------------------------------------------------------------------------


	#FAQ: 
	[error 1]: ERRO[0000] Get http://192.168.1.129:2375/v1.15/info: dial tcp 192.168.1.129:2375: getsockopt: connection refused 
	[solve]: set DOCKER_OPTS in /etc/default/docker of 192.168.129
	DOCKER_OPTS='-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -api-enable-cors'


###3.2 [host]: check container on each node


	# check docker container on swarm
	$./vm_nat.sh exec swarm "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.1.128 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS                    NAMES
	379c729f9199   swarm   "/swarm manage token:"   38 minutes ago   Up 38 minutes   0.0.0.0:23750->2375/tcp  agitated_turing
	---------------------------------------------------------------------------------------------------------------------------


	# check docker container on node1
	$./vm_nat.sh exec node1 "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.1.129 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID     IMAGE   COMMAND                  CREATED           STATUS           PORTS       NAMES
	8aea54398470     swarm   "/swarm join --addr=1"   47 minutes ago    Up 47 minutes    2375/tcp    backstabbing_pike
	---------------------------------------------------------------------------------------------------------------------------


	# check docker container on node2
	$./vm_nat.sh exec node2 "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.1.130 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID     IMAGE   COMMAND                  CREATED           STATUS           PORTS       NAMES
	e3bf2d09e1d7     swarm   "/swarm join --addr=1"   47 minutes ago    Up 47 minutes    2375/tcp    mad_bardeen
	---------------------------------------------------------------------------------------------------------------------------



#4 Access swarm cluster with docker client

	
###4.1 [docker client]access remote docker swarm by -H

	# view by swarm (manager)
	$ docker -H 192.168.1.128:23750 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB

	# view by node1(docker host)
	$ docker -H 192.168.1.129:2375 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB

	# view by node2(docker host)
	$ docker -H 192.168.1.130:2375 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB



###4.2 [docker client]access remote docker by setting DOCKER_HOST


	$ export DOCKER_HOST=192.168.1.128:23750


	$ docker images	
	REPOSITORY    TAG       IMAGE ID       CREATED       VIRTUAL SIZE
	swarm         latest    a9975e2cc0a3   12 days ago   17.15 MB
	busybox       latest    ac6a7980c6c2   13 days ago   1.113 MB


	$ docker pull nginx
	Using default tag: latest
	node2: Pulling nginx:latest... : downloaded 
	node1: Pulling nginx:latest... : downloaded 


	$ docker images
	REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
	nginx               latest              5328fdfe9b8e        6 days ago          133.9 MB
	swarm               latest              a9975e2cc0a3        13 days ago         17.15 MB
	busybox             latest              ac6a7980c6c2        2 weeks ago         1.113 MB


	$ docker ps -a
	CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS      NAMES
	e3bf2d09e1d7   swarm   "/swarm join --addr=1"   29 minutes ago   Up 29 minutes   2375/tcp   node2/mad_bardeen
	8aea54398470   swarm   "/swarm join --addr=1"   30 minutes ago   Up 30 minutes   2375/tcp   node1/backstabbing_pike


	$ docker info
	Containers: 2
	Images: 6
	Role: primary
	Strategy: spread
	Filters: health, port, dependency, affinity, constraint
	Nodes: 2
	 node1: 192.168.1.129:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.019 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-73-generic, operatingsystem=Ubuntu 14.04.3 LTS, storagedriver=aufs
	 node2: 192.168.1.130:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.019 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-73-generic, operatingsystem=Ubuntu 14.04.3 LTS, storagedriver=aufs
	CPUs: 2
	Total Memory: 2.038 GiB
	Name: 379c729f9199


#5 Start swarm cluster after vm reboot

	start container on node1, node2 -> start container on swarm

	# [host]start container on each vm
	$ ./vm_nat.sh exec node1 "docker start 8ae"
	$ ./vm_nat.sh exec node2 "docker start 379"
	$ ./vm_nat.sh exec swarm "docker start e3b"

	# [docker client]set DOCKER_HOST
	$ export DOCKER_HOST=192.168.1.128:23750
	$ docker images
	REPOSITORY    TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm         latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox       latest   ac6a7980c6c2   2 weeks ago   1.113 MB

#6 Manager Swarm Cluster

	
#7 Add node in Swarm Cluster

###7.1 add vm for node3

	# create a new vm with centos7(use dhcp)
	$ ./vm_nat.sh create centos7 node3 192.168.1.131

	# check node3
	$ ./vm_nat.sh list
	----------------------------------
	vmName	PID	mac_addr		guest_ip	backing_image
	node1	26206	52:54:00:96:9a:05	192.168.1.129	ubuntu14.04.img
	node2	30361	52:54:00:51:79:38	192.168.1.130	ubuntu14.04.img
	node3	30542	52:54:00:30:be:b3	192.168.1.131	centos7.img
	swarm	25552	52:54:00:12:61:35	192.168.1.128	ubuntu14.04.img

	# check docker daemon on node3
	$ docker -H 192.168.1.131:2375 images
	REPOSITORY    TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm         latest   a9975e2cc0a3   2 weeks ago   17.15 MB
	busybox       latest   ac6a7980c6c2   2 weeks ago   1.113 MB


###7.2 add node3 to Swarm Cluster

	# ssh to node3
	$ ./vm_nat.sh ssh node3

	# run on node3: (on each of your nodes, start the swarm agent)
	[root@node3 ~]# docker run -d --restart=always swarm join --addr=192.168.1.131:2375 token://08794256f34728021d1947832ae8bd88
	e76ba620c481ea5b4be5e1a7277f755968c9c237fc575114fcdb4a90a3ad7a5c

	[root@node3 ~]# docker ps
	CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS         PORTS      NAMES
	e76ba620c481   swarm   "/swarm join --addr=1"   13 seconds ago  Up 10 seconds  2375/tcp   silly_davinci

	# docker client connect to node3
	$ docker -H 192.168.1.131:2375 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   2 weeks ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB

	# check docker swarm cluster info (Swarm manager will auto discovery node3)
	$ export DOCKER_HOST=192.168.1.128:23750
	$ docker info
	Containers: 3
	Images: 14
	Role: primary
	Strategy: spread
	Filters: health, port, dependency, affinity, constraint
	Nodes: 3
	 node1: 192.168.1.129:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.019 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-73-generic, operatingsystem=Ubuntu 14.04.3 LTS, storagedriver=aufs
	 node2: 192.168.1.130:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.019 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-73-generic, operatingsystem=Ubuntu 14.04.3 LTS, storagedriver=aufs
	 node3: 192.168.1.131:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.018 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.10.0-229.14.1.el7.x86_64, operatingsystem=CentOS Linux 7 (Core), storagedriver=devicemapper
	CPUs: 3
	Total Memory: 3.057 GiB
	Name: 0fd0e7cac460

	# pull image for swarm cluster
	$ docker pull nginx
	Using default tag: latest
	node2: Pulling nginx:latest... : downloaded
	node1: Pulling nginx:latest... : downloaded
	node3: Pulling nginx:latest... : downloaded


#8 run container in Swarm Cluster

	$ export DOCKER_HOST=192.168.1.128:23750


###8.1 Run 4 nginx with 8888 port in 3 nodes, the last nginx can not start

	$ docker run --name nginx1 -p 8888:80 -d nginx
	db70b089a24abd4e80fddfe89e5d1241abcc985fecff086f923801d1c72df32e
	
	$ docker run --name nginx2 -p 8888:80 -d nginx
	267a840c9570796b3d1598f664650264a69089fd026d2f2a9223ac2ab5d80e10
	
	$ docker run --name nginx3 -p 8888:80 -d nginx
	501a9713c69a214cff01da1484d06d6b86539d167eb94766fcedd0810bf65c1f
	
	$ docker run --name nginx4 -p 8888:80 -d nginx
	Error response from daemon: unable to find a node with port 8888 available

	$ docker ps
	CONTAINER ID   IMAGE   COMMAND                  CREATED         STATUS         PORTS                                NAMES
	267a840c9570   nginx   "nginx -g 'daemon off"   3 minutes ago   Up 3 minutes   443/tcp, 192.168.1.129:8888->80/tcp  node1/nginx2
	501a9713c69a   nginx   "nginx -g 'daemon off"   3 minutes ago   Up 3 minutes   443/tcp, 192.168.1.131:8888->80/tcp  node3/nginx3
	db70b089a24a   nginx   "nginx -g 'daemon off"   3 minutes ago   Up 3 minutes   443/tcp, 192.168.1.130:8888->80/tcp  node2/nginx1 <=

	$ curl http://192.168.1.129:8888
	$ curl http://192.168.1.130:8888
	$ curl http://192.168.1.131:8888


###8.2 Run 3 nginx with 8888 port in 3 nodes, stop all nginx, run 1 tomcat
	
	$ docker stop nginx1 nginx2 nginx3

	$ docker run --name tomcat1 -p 8888:80 -d tomcat
	Error response from daemon: unable to find a node with port 8888 available

	$ docker rm -f nginx1
	nginx1

	$ docker run --name tomcat1 -p 8888:8080 -d tomcat
	72d09e18169d5959fa61b00e1681cf514c985383cbc4f32a5efd392721c412a0

	$ docker ps
	CONTAINER ID   IMAGE    COMMAND                  CREATED         STATUS         PORTS                                 NAMES
	72d09e18169d   tomcat   "catalina.sh run"        42 seconds ago  Up 47 seconds  192.168.1.130:8888->8080/tcp          node2/tomcat1 <=
	267a840c9570   nginx    "nginx -g 'daemon off"   9 minutes ago   Up 2 seconds   443/tcp, 192.168.1.129:8888->80/tcp   node1/nginx2
	501a9713c69a   nginx    "nginx -g 'daemon off"   9 minutes ago   Up 6 seconds   443/tcp, 192.168.1.131:8888->80/tcp   node3/nginx3

	$ curl http://192.168.1.130:8888