#image
	# get images
	http://docs.openstack.org/zh_CN/image-guide/content/ch_obtaining_images.html

	#ubuntu15.10(qcow2)
	http://cloud-images.ubuntu.com/releases/15.10/release-20151203/ubuntu-15.10-server-cloudimg-amd64-disk1.img

	#ubuntu14.04(qcow2)
	http://cloud-images.ubuntu.com/releases/14.04/release-20151217/ubuntu-14.04-server-cloudimg-amd64-disk1.img

	#debian(qcow2)
	http://cdimage.debian.org/cdimage/openstack/8.2.0/debian-8.2.0-openstack-amd64.qcow2

	#centos7(qcow2.xz)
	http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1510.qcow2.xz

	#centos6(qcow2.xz)
	http://cloud.centos.org/centos/6.6/images/CentOS-6-x86_64-GenericCloud-1510.qcow2.xz

	#fedora23(qcows.xz)
	http://mirrors.ustc.edu.cn/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-23-20151030.x86_64.raw.xz

	#fedora22(qcow2.xz)
	http://mirrors.ustc.edu.cn/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-22-20150521.x86_64.raw.xz

#usage

### prepare

	#install cloud-localds, generate seed.img
	make

	#download os image
	make ubuntu14.04
	make help # show all os image list


### for test

	./play.sh


### usage(nat, use ip)

	## Create new VM
	./vm_nat.sh create ubuntu14.04 node1
	./vm_nat.sh create ubuntu14.04 node2 192.168.122.128

	## Show VM list
	./vm_nat.sh list
	vmName	PID	mac_addr		guest_ip	backing_image
	node1	27699	52:54:00:ed:08:13	192.168.122.204	ubuntu14.04.img
	node2	28009	52:54:00:05:84:cc	192.168.122.128	ubuntu14.04.img <=

	## Run command line in VM though SSH
	./vm_nat.sh exec node1 "uname -a"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@192.168.122.119 "bash -c 'uname -a'"
	---------------------------------------------------------------------------------------------------------------------------
	Linux ubuntu 3.13.0-73-generic #116-Ubuntu SMP Fri Dec 4 15:31:30 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
	---------------------------------------------------------------------------------------------------------------------------


	## SSH to VM
	./vm_nat.sh ssh node1

	## change ip of node1
	./vm_nat.sh ssh node1
	root@ubuntu:~# ./set_ip.sh 192.168.122.200

	## Stop VM(kill qemu process, keep image file)
	./vm_nat.sh stop node1

	## Start VM from image file
	./vm_nat.sh start node1

	## Show VM list
	./vm_nat.sh list
	vmName	PID		mac_addr			guest_ip		backing_image
	node1	5620	52:54:00:05:36:89	192.168.122.119	ubuntu14.04.img
	node2	6287	52:54:00:8f:97:6f	192.168.122.200	ubuntu14.04.img <=

	## Shutdown VM(kill qemu process, delete image file)
	./vm_nat.sh shutdown node1


### usage(host, use port)

	## Create new VM
	./vm_host.sh create ubuntu14.04 node3 2223

	## Show VM list
	./vm_host.sh list
	vmName	port	PID		backing_image
	node3	2223	3539	ubuntu14.04.img

	## Run command line in VM though SSH
	./vm_host.sh exec node1 "uname -a"
	---------------------------------------------------------------------------------------------------------------------------
	> ssh -p2223 -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no  root@localhost "bash -c 'uname -a'"
	---------------------------------------------------------------------------------------------------------------------------
	Linux ubuntu 3.13.0-73-generic #116-Ubuntu SMP Fri Dec 4 15:31:30 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
	---------------------------------------------------------------------------------------------------------------------------


	## SSH to VM
	./vm_host.sh ssh node1

	## Stop VM(kill qemu process, keep image file)
	./vm_host.sh stop node1

	## Start VM from image file
	./vm_host.sh start node1 2222

	## Shutdown VM(kill qemu process, delete image file)
	./vm_host.sh shutdown node1

