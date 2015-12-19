#!/bin/bash


fn_show_usage() {
	if [ $# -ne 2 ];then
		cat <<EOF
usage:
	./run.sh <action> <option>
example: 
	./run.sh run node1 2222
	./run.sh list
	./run.sh exec node1 "top -b"
	./run.sh shutdown node1
	./run.sh ssh node1
EOF
	  exit 1
	fi
}

fn_run() {
	if [ $# -ne 2 ];then
		cat <<EOF
usage:
	./run.sh run <vm_name> <port>
example:
	./run.sh run node1 2222
EOF
		exit 1
	fi

	VM_NAME=$1
	SSH_PORT=$2
	echo "VM_NAME : ${VM_NAME}"
	echo "SSH_PORT: ${SSH_PORT}"
	echo

	echo "##### check vmName #####"
	ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | grep "\-name ${VM_NAME}"
	if [ $? -eq 0 ];then
		echo -e "\n[error]vmName ${VM_NAME} is in-used, please change the vm_name"
		exit 1
	fi

	echo "##### check port #####"
	netstat -tnopl | grep ":${SSH_PORT} "
	if [ $? -eq 0 ];then
		echo -e "\n[error]port ${SSH_PORT} is in-used, please change the port"
		exit 1
	fi

	echo "##### check the image #####"
	if [ -f _tmp/${VM_NAME}.img -o -f _tmp/${SSH_PORT} ];then
		echo -e "\n[error]image of ${VM_NAME} is existed, please change the vm_name, or clear the old one"
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
	# way1
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME}  -net nic -net user -hda $IMG -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22 &

	# way2
	#qemu-system-x86_64 -enable-kvm -net nic,model=virtio,macaddr=00:16:3e:3a:c0:99 -net tap,ifname=vnet10,script=no,downscript=no -hda $IMG -hdb _image/seed.img -m 1G -nographic -redir :2222::22 &

	#way3
	#sudo qemu-system-x86_64 \
	# -enable-kvm \
	# -name ${VM_NAME} \
	# -machine pc-i440fx-2.0,accel=kvm,usb=off \
	# -global kvm-pit.lost_tick_policy=discard \
	# -cpu host \
	# -realtime mlock=off \
	# -no-user-config \
	# -no-hpet \
	# -no-reboot \
	# -rtc base=utc,driftfix=slew \
	# -smp 1 \
	# -net nic -net user -hda $IMG -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22 &

	# remove the overlay (qemu will keep it open as needed)
	#sleep 10
	#rm $IMG
	#rm $SEED_IMG


	SSH_OPT="-p${SSH_PORT} -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

	# copy a script in (we could use Ansible for this kind of thing, but...)
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/test.sh xjimmy@localhost:~

	# run the script
	ssh ${SSH_OPT} xjimmy@localhost sudo ./test.sh

	# TODO run the benchmark

	# shut down the VM
	#ssh ${SSH_OPT} xjimmy@localhost sudo shutdown -h now

}

fn_list(){
	if [ $# -ne 0 ];then
		cat <<EOF
usage:
	./run.sh list
EOF
		exit 1
	fi
	echo -e "vmName\thPort\tvPort"
	ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if ($i=="-name"){printf "%s\t", $(i+1)};if (index($i,"::22")>0){split($i,p,":");printf "%s\t22\n", p[2]}} }'
}

fn_exec(){
	if [[ $# -ne 2 ]] || [[ -z $2 ]] ;then
		cat <<EOF
usage:
	./run.sh exec <vm_name> <command_line>
example:
	./run.sh exec node1 "top -b"
EOF
		exit 1
	fi
	VM_NAME=$1
	CMD_LINE=$2
	SSH_PORT=$(ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | grep "\-name ${VM_NAME}" | awk '{for (i=1;i<=NF;i++){if (index($i,"::22")>0){split($i,p,":");printf "%s\n", p[2]}} }')
	echo "VM_NAME: ${VM_NAME}"
	echo "SSH_PORT: ${SSH_PORT}"
	if [ -z ${SSH_PORT} ];then
		echo "can not find vmName: ${VM_NAME}"
		exit 1
	fi

	SSH_OPT="-p${SSH_PORT} -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

	echo -e "\n== Execute command in VM ================\n"
	echo "> ${CMD_LINE}"
	echo -e "\n== result ===============================\n"
	ssh ${SSH_OPT} xjimmy@localhost "bash -c '${CMD_LINE}'"
	echo -e "\n=========================================\n"
}

fn_shutdown(){
	if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./run.sh shutdown <vm_name>
example:
	./run.sh shutdown node1
EOF
		exit 1
	fi
	VM_NAME=$1
	fn_exec $VM_NAME "sudo shutdown -h now"
}

fn_ssh(){
if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./run.sh ssh <vm_name>
example:
	./run.sh ssh node1
EOF
		exit 1
	fi
	VM_NAME=$1

	SSH_PORT=$(ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | grep "\-name ${VM_NAME}" | awk '{for (i=1;i<=NF;i++){if (index($i,"::22")>0){split($i,p,":");printf "%s\n", p[2]}} }')
	echo "VM_NAME: ${VM_NAME}"
	echo "SSH_PORT: ${SSH_PORT}"
	if [ -z ${SSH_PORT} ];then
		echo "can not find vmName: ${VM_NAME}"
		exit 1
	fi

	SSH_OPT="-p${SSH_PORT} -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	ssh ${SSH_OPT} xjimmy@localhost
	echo -e "Goodbye!"

}

## main ###################################################
ACTION=$1
case ${ACTION} in
	run)
		fn_run $2 $3 #<vmName> <port>
		;;
	list)
		fn_list $2 $3
		;;
	exec)
		fn_exec $2 "$3"  #<vmName> <command>
		;;
	shutdown)
		fn_shutdown $2 $3 #<vmName>
		;;
	ssh)
		fn_ssh $2 $3
		;;
	*)
		fn_show_usage
		;;
esac
