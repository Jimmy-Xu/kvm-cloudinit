#OS Image(include cloud-init)
	
	# get cloud images
	http://docs.openstack.org/zh_CN/image-guide/content/ch_obtaining_images.html

	#ubuntu14.04(qcow2)
	http://cloud-images.ubuntu.com/releases/14.04/release-20151217/ubuntu-14.04-server-cloudimg-amd64-disk1.img

	#centos6(qcow2.xz)
	http://cloud.centos.org/centos/6.6/images/CentOS-6-x86_64-GenericCloud-1510.qcow2.xz

	#fedora23(qcows.xz)
	http://mirrors.ustc.edu.cn/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-23-20151030.x86_64.raw.xz

	#fedora22(qcow2.xz)
	http://mirrors.ustc.edu.cn/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-22-20150521.x86_64.raw.xz



#Usage

### Prepare VM

	#prepare dir, install cloud-localds
	make

	#download cloud image
	make ubuntu14.04
	make help # show all cloud image list


### Test kvm environment

	./play.sh


### Usage

#### Basic Usage

	## config network and bridge
	vi etc/config

	### for NAT network
	BR=virbr0
	NETWORK_PREFIX=192.168.122
	HOST_IP=192.168.122.1
	
	### for Bridge network
	BR=br0
	NETWORK_PREFIX=192.168.1
	HOST_IP=192.168.1.141


	## Create new VM

	### dhcp
	./vm_nat.sh swarm create ubuntu14.04 node1
	
	### static ip
	./vm_nat.sh swarm create ubuntu14.04 node2 192.168.122.128


	## Show VM list
	./vm_nat.sh swarm list
	VMNAME		PID		MAC_ADDR			CURRENT_IP		IP_TYPE	CONFIG_IP		BACKING_IMAGE
	node1       8584	52:54:00:7f:8f:10	192.168.122.129	dhcp	---.---.---.---	ubuntu14.04.img
	swarm       7583	52:54:00:29:6d:7a	192.168.122.128	static	192.168.122.130	ubuntu14.04.img


	## Run command line in VM though SSH
	./vm_nat.sh swarm exec node1 "uname -a"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.119 "bash -c 'uname -a'"
	---------------------------------------------------------------------------------------------------------------------------
	Linux ubuntu 3.13.0-73-generic #116-Ubuntu SMP Fri Dec 4 15:31:30 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
	---------------------------------------------------------------------------------------------------------------------------

	## Shutdown VM(kill qemu process, delete image file)
	./vm_nat.sh swarm shutdown node1

#### Example: Clone vm (node1 -> node2)

	stop src_vm -> clone -> start src_vm -> start tgt_vm 
	
	## Stop node1
	$ ./vm_nat.sh swarm stop node1

	## Clone node1 to node2(all stopped)
	$ ./vm_nat.sh swarm clone node1 node2

	## Start node1(with config_ip[dhcp/static_ip])
	$ ./vm_nat.sh swarm start node1

	## Start node2(with static_ip)
	$ ./vm_nat.sh swarm start node2 192.168.122.130

	## Show VM list again
	$ ./vm_nat.sh swarm list
	VMNAME	PID		MAC_ADDR			CURRENT_IP		IP_TYPE	CONFIG_IP		BACKING_IMAGE
	node1   8584	52:54:00:7f:8f:10	192.168.122.129	dhcp	---.---.---.---	ubuntu14.04.img
	node2   9213	52:54:00:00:7a:5b	192.168.122.130	static	192.168.122.130	ubuntu14.04.img
	swarm   7583	52:54:00:29:6d:7a	192.168.122.128	static	192.168.122.128	ubuntu14.04.img


#### Example: connect remote docker daemon
	
	## pull image
	$ docker -H 192.168.122.128:2375 pull busybox
	Using default tag: latest

	## run container
	$ docker -H 192.168.122.128:2375 run -it --rm busybox uname -a
	Linux b7e3cbe32ab3 3.13.0-73-generic #116-Ubuntu SMP Fri Dec 4 15:31:30 UTC 2015 x86_64 GNU/Linux

	## set env
	$ export DOCKER_HOST=192.168.122.128:2375
	$ docker pull swarm
	
	# show images (1)
	$ docker images
	REPOSITORY   TAG      IMAGE ID       CREATED       VIRTUAL SIZE
	swarm        latest   a9975e2cc0a3   12 days ago   17.15 MB
	busybox      latest   ac6a7980c6c2   13 days ago   1.113 MB

	# show images (2)
	$./vm_nat.sh swarm exec node2 "docker images"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.128 "bash -c 'docker images'"
	---------------------------------------------------------------------------------------------------------------------------
	REPOSITORY    TAG       IMAGE ID        CREATED       VIRTUAL SIZE
	swarm         latest    a9975e2cc0a3    12 days ago   17.15 MB
	busybox       latest    ac6a7980c6c2    13 days ago   1.113 MB
	---------------------------------------------------------------------------------------------------------------------------
