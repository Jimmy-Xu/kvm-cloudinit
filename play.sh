#!/bin/bash

#make ubuntu-13.10-server-cloudimg-amd64-disk1.img seed.img
make ubuntu-14.04-server-cloudimg-amd64-disk1.img seed.img play-trusty.img

# create ephemeral overlay qcow image
# (we probably could have used -snapshot)
IMG=`mktemp _tmp/tmpXXX.img`
#qemu-img create -f qcow2 -b ubuntu-13.10-server-cloudimg-amd64-disk1.img $IMG
qemu-img create -f qcow2 -b `pwd`/_base_image/ubuntu-14.04-server-cloudimg-amd64-disk1.img $IMG

# start the VM
sudo qemu-system-x86_64 -enable-kvm -net nic -net user -hda $IMG -hdb _image/seed.img -m 1G -nographic -redir :2222::22 &
#qemu-system-x86_64 -enable-kvm -net nic,model=virtio,macaddr=00:16:3e:3a:c0:99 -net tap,ifname=vnet10,script=no,downscript=no -hda $IMG -hdb _image/seed.img -m 1G -nographic -redir :2222::22 &

# remove the overlay (qemu will keep it open as needed)
sleep 3
rm $IMG


SSH_OPT="-p2222 -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

# copy a script in (we could use Ansible for this kind of thing, but...)
rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/test.sh xjimmy@localhost:~

# run the script
ssh ${SSH_OPT} xjimmy@localhost ./test.sh

# TODO run the benchmark

# shut down the VM
ssh ${SSH_OPT} xjimmy@localhost sudo shutdown -h now

