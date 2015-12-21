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


### usage

	## Create new VM
	./vm.sh run node1 2222
	./vm.sh run node2 2223

	## Show VM list
	./vm.sh list

	## Run command line in VM though SSH
	./vm.sh exec node1 "top -b"

	## SSH to VM
	./vm.sh ssh node1

	## Stop VM(kill qemu process, keep image file)
	./vm.sh stop node1

	## Start VM from image file
	./vm.sh start ubuntu14.04 node1 2222

	## Shutdown VM(kill qemu process, delete image file)
	./vm.sh shutdown node1
