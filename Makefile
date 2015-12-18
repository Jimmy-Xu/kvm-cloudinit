all: init cloud-localds cirros coreos ubuntu-14.04-server-cloudimg-amd64-disk1.img seed.img play-trusty.img

# init
init:
	@echo
	@echo  "----- init  -----"
	@mkdir -p _base_image _deps _image _tmp
	@chmod 400 etc/.ssh/id_rsa

# install cloud-localds
cloud-localds:
	@echo
	@echo  "----- install cloud-localds -----";
	@if [ ! -f /usr/local/bin/cloud-localds ];then \
		sudo apt-get install cloud-utils;\
                cd _deps;\
		wget -c https://launchpad.net/cloud-utils/trunk/0.27/+download/cloud-utils-0.27.tar.gz;\
		tar xzvf cloud-utils-0.27.tar.gz;\
		sudo cp cloud-utils-0.27/bin/cloud-localds /usr/local/bin;\
		cd -;\
	else \
		echo "cloud-localds already installed";\
	fi

# download image: ubuntu-14.04
ubuntu-14.04-server-cloudimg-amd64-disk1.img:
	@echo
	@echo  "----- download image: ubuntu-14.04  -----"
	@wget -c http://cloud-images.ubuntu.com/releases/14.04/release-20151217/ubuntu-14.04-server-cloudimg-amd64-disk1.img -O _base_image/ubuntu-14.04-server-cloudimg-amd64-disk1.img

# download image: cirros-0.3.4
cirros:
	@echo
	@echo  "----- download image: cirros-0.3.4 -----"
	wget -c http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img -O _base_image/cirros-0.3.4-x86_64-disk.img;

# download image: coreos
coreos:
	@echo
	@echo  "----- download image: coreos  -----"
	@if [ ! -f _base_image/coreos_production_qemu_image.img ];then \
		wget -c  http://stable.release.core-os.net/amd64-usr/current/coreos_production_qemu_image.img.bz2 -O _base_image/coreos_production_qemu_image.img.bz2;\
		bzcat -v _base_image/coreos_production_qemu_image.img.bz2 > _base_image/coreos_production_qemu_image.img;\
	else \
		echo "coreos_production_qemu_image.img already downloaded";\
	fi

# convert user data into an ISO image
seed.img: etc/user-data
	@echo
	@echo "----- convert user data into an ISO image -----"
	@cloud-localds _image/seed.img etc/user-data

# build a qcow layer
play-trusty.img: ubuntu-14.04-server-cloudimg-amd64-disk1.img
	@echo
	@echo "----- build a qcow layer -----"
	@qemu-img create -f qcow2 -b `pwd`/_base_image/ubuntu-14.04-server-cloudimg-amd64-disk1.img ./_image/play.img


# clean
clean:
	@echo
	@echo "----- clean  -----"
	@rm -rf _base_image/* _deps/* _image/* _tmp/*

