#QuickStart: Create Docker Universal Control Plane

https://github.com/docker/ucp_lab

## 1.prepare

	# install kvm, libvirt and cloud-localds
	$ make
	$ make ubuntu14.04

## 2.require

	free disk space: 3GB+
	free memory: 1.5GB+
	kernel version: 3.16.0+

## 3.create vm

	+-------------------------------------host--------------------------------------+
	|                                                                               |
	|                            +---------vm----------+                            |
	|                            |                     |                            |
	|                            |  +----docker-----+  |                            |
	|                            |  |               |  |                            |
	|                            |  |  +---------+  |  |                            |
	|                            |  |  | ducp-0  |  |  |                            |
	|                            |  |  +---------+  |  |                            |
	|                            |  |               |  |                            |
	|                            |  +---------------+  |                            |
	|                            |     ubuntu14.04     |                            |
	|                            +---192.168.122.200---+                            |
	|                                                                               |
	|            +---------vm----------+          +---------vm----------+           |
	|            |                     |          |                     |           |
	|            |  +----docker-----+  |          |  +----docker-----+  |           |
	|            |  |               |  |          |  |               |  |           |
	|            |  |  +---------+  |  |          |  |  +---------+  |  |           |
	|            |  |  | ducp-1  |  |  |          |  |  | ducp-2  |  |  |           |
	|            |  |  +---------+  |  |          |  |  +---------+  |  |           |
	|            |  |               |  |          |  |               |  |           |
	|            |  +---------------+  |          |  +---------------+  |           |
	|            |     ubuntu14.04     |          |     ubuntu14.04     |           |
	|            +---192.168.122.201---+          +---192.168.122.202---+           |
	|                                                                               |
	+-------------------------------------------------------------------------------+

	#create three vm

	## create one VM, clone another two VM
	$ ./vm_nat.sh ducp create ubuntu14.04 ducp-0 192.168.122.200

	### update kernel from 3.13 to 3.16
	$ ./vm_nat.sh ducp ssh ducp-0
	[root@ducp-0 ~:]# apt-get install linux-generic-lts-vivid
	[root@ducp-0 ~:]# reboot

	### check requirement
	$ ./vm_nat.sh ducp ssh ducp-0
	[root@ducp-0 ~:]# uname -r
	3.19.0-43-generic
	[root@ducp-0 ~:]# df -hT | grep /$
	/dev/sda1      ext4      5.1G  1.9G  3.1G  38% /
	[root@ducp-0 ~:]# free -m | head -n 2
            total       used       free     shared    buffers     cached
	Mem:     1597        146       1450          0          8         80

	## Run the UCP installer on ducp-0
	[root@ducp-0 ~:]# docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock --name ucp dockerorca/ucp install -i
	Error: image dockerorca/ucp-controller:latest not found
	Error: image dockerorca/ucp-etcd:2.2.0 not found
