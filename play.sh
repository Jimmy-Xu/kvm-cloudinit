#!/bin/bash

make ubuntu14.04 

# create ephemeral overlay qcow image
# (we probably could have used -snapshot)
IMG=`mktemp tmpXXX.img`
SEED_IMG="seed-${IMG}"
echo "----- create temp image image: $IMG -----"
qemu-img create -f qcow2 -b `pwd`/_base_image/ubuntu14.04.img $IMG

echo "----- convert user data into an ISO image: ${SEED_IMG} -----"
sed "s/{HOSTNAME}/${TMP}/" etc/user-data.dhcp > etc/user-data
cloud-localds ${SEED_IMG} etc/user-data


# start the VM
echo "----- create vm -----"
sudo pwd
sudo qemu-system-x86_64 -name ${IMG} -enable-kvm -net nic -net user -hda $IMG -hdb ${SEED_IMG} -m 1G -nographic -redir :2222::22 &

# remove the overlay (qemu will keep it open as needed)
sleep 2
rm -rf $IMG $SEED_IMG


SSH_OPT="-p2222 -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

#check ip
echo "check guest ip"
cnt=1
ssh ${SSH_OPT} root@localhost ifconfig
while [[ $? -ne 0 ]]
do
	echo "$cnt: waiting for guest ip..."
	sleep 1
	cnt=$((cnt + 1))
	ssh ${SSH_OPT} root@localhost ifconfig
done


# copy a script in (we could use Ansible for this kind of thing, but...)
echo "copy test.sh to vm..."
rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/test.sh root@localhost:~

# run the script
echo "run test.sh..."
ssh ${SSH_OPT} root@localhost ./test.sh

# shut down the VM
echo "shutdown vm..."
ssh ${SSH_OPT} root@localhost shutdown -h now
