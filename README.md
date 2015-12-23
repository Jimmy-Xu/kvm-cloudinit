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
	./vm_nat.sh create ubuntu14.04 node1
	### static ip
	./vm_nat.sh create ubuntu14.04 node2 192.168.122.128

	## Show VM list
	./vm_nat.sh list
	vmName	PID	mac_addr		guest_ip	backing_image
	node1	27699	52:54:00:ed:08:13	192.168.122.204	ubuntu14.04.img <=
	node2	28009	52:54:00:05:84:cc	192.168.122.128	ubuntu14.04.img

	## Run command line in VM though SSH
	./vm_nat.sh exec node1 "uname -a"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.119 "bash -c 'uname -a'"
	---------------------------------------------------------------------------------------------------------------------------
	Linux ubuntu 3.13.0-73-generic #116-Ubuntu SMP Fri Dec 4 15:31:30 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
	---------------------------------------------------------------------------------------------------------------------------

	## Shutdown VM(kill qemu process, delete image file)
	./vm_nat.sh shutdown node1

#### Example: Clone vm (node1 -> node2)

	stop -> clone -> change ip of src_vm -> start src_vm -> start tgt_vm 
	
	## Stop node1
	$ ./vm_nat.sh stop node1

	## Clone node1 to swarm(all stopped)
	$ ./vm_nat.sh clone node1 swarm

	## Start node1
	$ ./vm_nat.sh start node1

	## connect to node1
	$ ./vm_nat.sh ssh node1
	
	##run the following command in vm
	root@node1:~# ./set_ip.sh 192.168.122.200
	root@node1:~# exit

	## Stop VM(kill qemu process, keep image file)
	$ ./vm_nat.sh stop node1

	## Start node1
	$ ./vm_nat.sh start node1

	## Start swarm
	$ ./vm_nat.sh start swarm

	## Show VM list again
	$ ./vm_nat.sh list
	vmName	PID		mac_addr			guest_ip		backing_image
	node1	29668	52:54:00:46:33:61	192.168.122.100	ubuntu14.04.img <=
	node2	30685	52:54:00:a3:64:67	192.168.122.128	ubuntu14.04.img
	swarm	29931	52:54:00:de:3b:a3	192.168.122.200	ubuntu14.04.img <=


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
	$./vm_nat.sh exec node2 "docker images"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.128 "bash -c 'docker images'"
	---------------------------------------------------------------------------------------------------------------------------
	REPOSITORY    TAG       IMAGE ID        CREATED       VIRTUAL SIZE
	swarm         latest    a9975e2cc0a3    12 days ago   17.15 MB
	busybox       latest    ac6a7980c6c2    13 days ago   1.113 MB
	---------------------------------------------------------------------------------------------------------------------------
