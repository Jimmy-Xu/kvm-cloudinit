#Create a docker swarm cluster 

	- three kvm VM
		- install docker
		- pull swarm image
	- three docker container
		- swarm: cluster manager
		- node1: docker host
		- node2: docker host


#1 prepare VM


	# create three VMs
	./vm_nat.sh create ubuntu14.04 swarm 192.168.122.128
	./vm_nat.sh create ubuntu14.04 node1 192.168.122.129
	./vm_nat.sh create ubuntu14.04 node2 192.168.122.130


	# show vm info
	$./vm_nat.sh list
	vmName	PID		mac_addr			guest_ip		backing_image
	node1	3299	52:54:00:af:e7:7b	192.168.122.129	ubuntu14.04.img
	node2	3510	52:54:00:76:a7:69	192.168.122.130	ubuntu14.04.img
	swarm	3041	52:54:00:d5:a9:12	192.168.122.128	ubuntu14.04.img



#2 configure cluster


###2.1 [swarm]: create cluster

	$ docker run --rm swarm create
	e19f223cfa60ba1349e1f414dd02cd2e # <- this is <cluster_id>


###2.2 [node1]: join to cluster (on each of your nodes, start the swarm agent)
	
	$ docker run -d swarm join --addr=192.168.122.129:2375 token://e19f223cfa60ba1349e1f414dd02cd2e
	8aea54398470ec76f71d5b53cfd1f357f88307104c46e328e2a6a60802e4ab14


###2.3 [node2]: join to cluster (on each of your nodes, start the swarm agent)
	
	$ docker run -d swarm join --addr=192.168.122.130:2375 token://e19f223cfa60ba1349e1f414dd02cd2e
	e3bf2d09e1d7de6deaa8bde94a4b2b2f14981bb336f5896ade0c34b07a935b6b


#3 Start the manager 

###3.1 [swarm]: start service
	docker run -t -p 23750:2375 -t swarm manage token://e19f223cfa60ba1349e1f414dd02cd2e
	INFO[0000] Listening for HTTP                            addr=:2375 proto=tcp
	INFO[0001] Registered Engine node1 at 192.168.122.129:2375 
	INFO[0001] Registered Engine node2 at 192.168.122.130:2375 



###3.2 [host]: check container on each node


	# check swarm service
	$ ./vm_nat.sh exec swarm "netstat -tnopl"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.128 "bash -c 'netstat -tnopl'"
	---------------------------------------------------------------------------------------------------------------------------
	Active Internet connections (only servers)
	Proto Recv-Q Send-Q Local Address     Foreign Address  State     PID/Program name Timer
	tcp6       0      0 :::23750          :::*             LISTEN    12359/docker-proxy off (0.00/0/0)
	tcp6       0      0 :::2375           :::*             LISTEN    12027/docker     off (0.00/0/0)
	---------------------------------------------------------------------------------------------------------------------------


	# check docker container on swarm
	$./vm_nat.sh exec swarm "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.128 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS                    NAMES
	379c729f9199   swarm   "/swarm manage token:"   38 minutes ago   Up 38 minutes   0.0.0.0:23750->2375/tcp  agitated_turing
	---------------------------------------------------------------------------------------------------------------------------


	# check docker container on node1
	$./vm_nat.sh exec node1 "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.129 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID     IMAGE   COMMAND                  CREATED           STATUS           PORTS       NAMES
	8aea54398470     swarm   "/swarm join --addr=1"   47 minutes ago    Up 47 minutes    2375/tcp    backstabbing_pike
	---------------------------------------------------------------------------------------------------------------------------


	# check docker container on node2
	$./vm_nat.sh exec node2 "docker ps"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.130 "bash -c 'docker ps'"
	---------------------------------------------------------------------------------------------------------------------------
	CONTAINER ID     IMAGE   COMMAND                  CREATED           STATUS           PORTS       NAMES
	e3bf2d09e1d7     swarm   "/swarm join --addr=1"   47 minutes ago    Up 47 minutes    2375/tcp    mad_bardeen
	---------------------------------------------------------------------------------------------------------------------------



#4 access swarm with docker client

	
###4.1 [docker client]access remote docker swarm by -H

	# view by swarm (manager)
	$ docker -H 192.168.122.128:23750 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB

	# view by node1(docker host)
	$ docker -H 192.168.122.129:2375 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB

	# view by node2(docker host)
	$ docker -H 192.168.122.130:2375 images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   2 weeks ago   1.113 MB



###4.2 [docker client]access remote docker by setting DOCKER_HOST


	$ export DOCKER_HOST=192.168.122.128:23750


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
	 node1: 192.168.122.129:2375
	  └ Status: Healthy
	  └ Containers: 1
	  └ Reserved CPUs: 0 / 1
	  └ Reserved Memory: 0 B / 1.019 GiB
	  └ Labels: executiondriver=native-0.2, kernelversion=3.13.0-73-generic, operatingsystem=Ubuntu 14.04.3 LTS, storagedriver=aufs
	 node2: 192.168.122.130:2375
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
	./vm_nat.sh exec node1 "docker start 8ae"
	./vm_nat.sh exec node2 "docker start 379"
	./vm_nat.sh exec swarm "docker start e3b"

	# [docker client]set DOCKER_HOST
	$ export DOCKER_HOST=192.168.122.128:23750
	$ docker images
	REPOSITORY    TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm         latest   a9975e2cc0a3   13 days ago   17.15 MB
	busybox       latest   ac6a7980c6c2   2 weeks ago   1.113 MB
