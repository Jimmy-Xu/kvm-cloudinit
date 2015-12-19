#!/bin/bash

VM_NAME=$1
SSH_PORT=$2

if [ $# -ne 2 ];then
	cat <<EOF
  usage: ./run.sh <vm_name> <port>
  example: ./run.sh node1 2222
EOF
  exit 1
fi

echo "VM_NAME : ${VM_NAME}"
echo "SSH_PORT: ${SSH_PORT}"
echo

echo "##### check port #####"
netstat -tnopl | grep ":${SSH_PORT} "
if [ $? -eq 0 ];then
	echo "port ${SSH_PORT} is in-used, please change the port"
	exit 1
fi


echo ##### prepare image #####"
make ubuntu-14.04-server-cloudimg-amd64-disk1.img seed.img play-trusty.img

# create ephemeral overlay qcow image
# (we probably could have used -snapshot)
IMG="_tmp/${VM_NAME}.img"
qemu-img create -f qcow2 -b `pwd`/_base_image/ubuntu-14.04-server-cloudimg-amd64-disk1.img $IMG

SEED_IMG="_tmp/${VM_NAME}-seed.img"
qemu-img create -f qcow2 -b `pwd`/_image/seed.img $SEED_IMG

echo "##### list images for ${VM_NAME} #####"
ls _tmp/${VM_NAME}*

sleep 1

echo -e "\n##### start the VM #####"
sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME}  -net nic -net user -hda $IMG -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22 &
#qemu-system-x86_64 -enable-kvm -net nic,model=virtio,macaddr=00:16:3e:3a:c0:99 -net tap,ifname=vnet10,script=no,downscript=no -hda $IMG -hdb _image/seed.img -m 1G -nographic -redir :2222::22 &

# remove the overlay (qemu will keep it open as needed)
sleep 10
rm $IMG
rm $SEED_IMG


SSH_OPT="-p${SSH_PORT} -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

# copy a script in (we could use Ansible for this kind of thing, but...)
rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/test.sh spyre@localhost:~

# run the script
ssh ${SSH_OPT} spyre@localhost sudo ./test.sh

# TODO run the benchmark

# shut down the VM
ssh ${SSH_OPT} spyre@localhost sudo shutdown -h now

