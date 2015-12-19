#image

	see http://ubuntu-smoser.blogspot.co.uk/2013/02/using-ubuntu-cloud-images-without-cloud.html  
	or http://cloud-images.ubuntu.com/releases or http://uec-images.ubuntu.com/trusty/current/  
	or http://docs.openstack.org/zh_CN/image-guide/content/ch_obtaining_images.html  

#usage

	make
	./play.sh


	## Create new VM
	./vm.sh run node1 2222
	./vm.sh run node2 2223

	## Show VM list
	./vm.sh list

	## Run command line in VM though SSH
	./vm.sh exec node1 "top -b"

	## SSH to VM
	./vm.sh ssh

	## Stop VM(kill qemu process, keep image file)
	./vm.sh stop node1

	## Start VM from image file
	./vm.sh start node1 2222

	## Shutdown VM(kill qemu process, delete image file)
	./vm.sh shutdown node1
