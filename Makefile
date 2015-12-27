all: init kvm cloud-localds

# init
init:
	@echo
	@echo  "----- init  -----"
	@mkdir -p _base_image _deps _image _tmp/host _tmp/nat
	@chmod 400 etc/.ssh/id_rsa

######################################################################
# download ubuntu15.10(qcow2)
ubuntu15.10:
	@echo
	@echo "----- download image: ubuntu15.10 -----"
	@wget -c http://cloud-images.ubuntu.com/releases/15.10/release-20151203/ubuntu-15.10-server-cloudimg-amd64-disk1.img -O _base_image/ubuntu15.10.img

# download ubuntu14.04(qcow2 + cloud-init)
ubuntu14.04:
	@echo
	@echo "----- download image: ubuntu-14.04 -----"
	@wget -c http://cloud-images.ubuntu.com/releases/14.04/release-20151217/ubuntu-14.04-server-cloudimg-amd64-disk1.img -O _base_image/ubuntu14.04.img

# download debian(qcow2)
debian8.2:
	@echo
	@echo "----- download image: debian8.2 -----"
	@wget -c http://cdimage.debian.org/cdimage/openstack/8.2.0/debian-8.2.0-openstack-amd64.qcow2 -O _base_image/debian8.2.img

# download centos7(qcow2.xz)
centos7:
	@echo
	@echo "----- download image: centos7 -----"
	@if [ ! -s _base_image/centos7.img ];then \
		wget -c http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1510.qcow2.xz -O _base_image/centos7.img.xz; \
		xz -v -d --keep _base_image/centos7.img.xz; \
	else \
		echo '_base_image/centos7.img already existed'; \
	fi

# download centos6(qcow2.xz + cloud-init)
centos6:
	@echo
	@echo "----- download image: centos6 -----"
	@if [ ! -s _base_image/centos6.img ];then \
		wget -c http://cloud.centos.org/centos/6.6/images/CentOS-6-x86_64-GenericCloud-1510.qcow2.xz -O _base_image/centos6.img.xz; \
		xz -v -d --keep _base_image/centos6.img.xz; \
	else \
		echo '_base_image/centos6.img already existed'; \
	fi

# download fedora23(qcow2 + cloud-init)
fedora23:
	@echo
	@echo "----- download image: fedora23 -----"
	@wget -c http://mirrors.ustc.edu.cn/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-23-20151030.x86_64.qcow2 -O _base_image/fedora23.img;

# download fedora22(qcow2 + cloud-init)
fedora22:
	@echo
	@echo "----- download image: fedora22 -----"
	@wget -c http://mirrors.ustc.edu.cn/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-22-20150521.x86_64.qcow2 -O _base_image/fedora22.img;

# # download image: cirros-0.3.4
# cirros:
# 	@echo "----- download image: cirros-0.3.4 -----"
# 	@wget -c http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -O _base_image/cirros.img

# # download image: coreos
# coreos:
# 	@echo "----- download image: coreos  -----"
# 	@if [ ! -s _base_image/coreos.img ];then \
# 		wget -c  http://stable.release.core-os.net/amd64-usr/current/coreos_production_qemu_image.img.bz2 -O _base_image/coreos.img.bz2;\
# 		bzcat -v _base_image/coreos.img.bz2 > _base_image/coreos.img;\
# 	else \
# 		echo "_base_image/coreos.img already downloaded";\
# 	fi
######################################################################

# install kvm libvirt
kvm:
	@echo
	@echo "----- install kvm and libvirt -----"
	@sudo apt-get install qemu qemu-kvm libvirt-bin
	@echo "----- check after installed -----"
	@qemu-system-x86_64 --version && sudo ifconfig virbr0 && echo "qemu and libvirt installed succeed!" || echo "qemu or libvirt installed failed!"

# install cloud-localds
cloud-localds:
	@echo
	@echo  "----- install cloud-localds -----";
	@if [ ! -s /usr/local/bin/cloud-localds ];then \
		sudo apt-get install cloud-utils;\
                cd _deps;\
		wget -c https://launchpad.net/cloud-utils/trunk/0.27/+download/cloud-utils-0.27.tar.gz;\
		tar xzvf cloud-utils-0.27.tar.gz;\
		sudo cp cloud-utils-0.27/bin/cloud-localds /usr/local/bin;\
		cd -;\
	else \
		echo "cloud-localds already installed";\
	fi

# convert user data into an ISO image
# seed.img: etc/user-data
# 	@echo
# 	@echo "----- convert user data into an ISO image -----"
# 	@cloud-localds _image/seed.img etc/user-data

# # build a qcow layer
# play-trusty.img: ubuntu-14.04-server-cloudimg-amd64-disk1.img
# 	@echo
# 	@echo "----- build a qcow layer -----"
# 	@qemu-img create -f qcow2 -b `pwd`/_base_image/ubuntu-14.04-server-cloudimg-amd64-disk1.img ./_image/play.img


# clean
clean:
	@echo
	@echo "----- clean  -----"
	@rm -rf _base_image/* _deps/* _image/* _tmp/*

help:
	@echo "# init dir and install cloud-localds"
	@echo "  make"
	@echo "# download image"
	@echo "  make ubuntu15.10"
	@echo "  make ubuntu14.04"
	@echo "  make debian8.2"
	@echo "  make centos7"
	@echo "  make centos6"
	@echo "  make fedora23"
	@echo "  make fedora22"
