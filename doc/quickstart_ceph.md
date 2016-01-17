QuickStart: Create Ceph Cluster
========================================================

1.prepare
--------------------------------------------------------

		# install kvm, libvirt and cloud-localds
		$ make
		$ make ubuntu14.04


2.require
--------------------------------------------------------

free disk space: 3GB+
free memory: 1.5GB+
kernel version: 3.16.0+


3.test single node ceph
--------------------------------------------------------

### run ceph-demo container

		$ HOST_IP=`(grep " $(ip route list 0/0 | awk '{print $NF}').*src" <(ip route)) | grep -v default | awk '{print $NF}'`
		$ PREFIX=`(grep " $(ip route list 0/0 | awk '{print $NF}').*src" <(ip route)) | grep -v default | awk '{print $1}'`
		$ docker run -d --name=ceph-demo --net=host -e MON_IP=${HOST_IP} -e CEPH_NETWORK=${PREFIX} ceph/demo

### view ceph-demo status

	$ docker exec -it ceph-demo ceph status
		cluster 83fbd344-7b4f-46c9-a9c4-c5ee2de636d4
		 health HEALTH_WARN
						mon.mini-ubuntu low disk space
		 monmap e1: 1 mons at {mini-ubuntu=192.168.1.137:6789/0}
						election epoch 2, quorum 0 mini-ubuntu
		 mdsmap e4: 1/1/1 up {0=0=up:active}
		 osdmap e16: 1 osds: 1 up, 1 in
						flags sortbitwise
			pgmap v22: 128 pgs, 9 pools, 2808 bytes data, 190 objects
						32925 MB used, 11480 MB / 46805 MB avail
								 128 active+clean

		$ docker exec -it ceph-demo ceph -w
				2016-01-16 15:40:48.934054 mon.0 [INF] pgmap v22: 128 pgs: 128 active+clean; 2808 bytes data, 32925 MB used, 11480 MB / 46805 MB avail
				2016-01-16 15:42:48.950706 mon.0 [INF] pgmap v23: 128 pgs: 128 active+clean; 2808 bytes data, 32925 MB used, 11480 MB / 46805 MB avail
				2016-01-16 15:43:03.953237 mon.0 [INF] pgmap v24: 128 pgs: 128 active+clean; 2808 bytes data, 32925 MB used, 11480 MB / 46805 MB avail

		#list pool
		$	docker exec -it ceph-demo rados lspools
				rbd
				cephfs_data
				cephfs_metadata
				.rgw.root
				.rgw.control
				.rgw
				.rgw.gc
				.log
				.users.uid

		#show pool info
		$ docker exec -it ceph-demo rados -p .rgw.root ls  
				default.region
				region_info.default
				zone_info.default

		#get the current capacity for OSD
		$ docker exec -it ceph-demo rados df    
				pool name                 KB      objects       clones     degraded      unfound           rd        rd KB           wr        wr KB
				.log                       0          127            0            0            0         1905         1778         1270            0
				.rgw                       0            0            0            0            0            0            0            0            0
				.rgw.control               0            8            0            0            0            0            0            0            0
				.rgw.gc                    0           32            0            0            0           96           64           64            0
				.rgw.root                  1            3            0            0            0            0            0            3            3
				.users.uid                 0            0            0            0            0            0            0            0            0
				cephfs_data                0            0            0            0            0            0            0            0            0
				cephfs_metadata            2           20            0            0            0            0            0           41            7
				rbd                        0            0            0            0            0            0            0            0            0
				  total used        33718060          190
				  total avail       11753412
				  total space       47929224


### Create Bucket

		$ docker exec -it ceph-demo ceph osd crush add-bucket rack01 rack
			added bucket rack01 type rack to crush map
		$ docker exec -it ceph-demo ceph osd crush add-bucket rack02 rack
			added bucket rack01 type rack to crush map
		$ docker exec -it ceph-demo ceph osd crush add-bucket rack03 rack
			added bucket rack01 type rack to crush map

		$	docker exec -it ceph-demo ceph osd tree                        
			ID WEIGHT  TYPE NAME            UP/DOWN REWEIGHT PRIMARY-AFFINITY
			-5       0 rack rack03                                            
			-4       0 rack rack02                                            
			-3       0 rack rack01                                            
			-1 1.00000 root default                                           
			-2 1.00000     host mini-ubuntu                                   
			 0 1.00000         osd.0             up  1.00000          1.00000
