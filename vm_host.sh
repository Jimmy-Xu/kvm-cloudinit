#!/bin/bash


fn_show_usage() {
	if [ $# -ne 2 ];then
		cat <<EOF
usage:
	./vm_host.sh <action> <option>
example: 
	./vm_host.sh images
	./vm_host.sh create ubuntu14.04 node1 2222
	./vm_host.sh list
	./vm_host.sh exec node1 "top -b"
	./vm_host.sh ssh node1
	./vm_host.sh stop node1
	./vm_host.sh start node1 2222
	./vm_host.sh shutdown node1

EOF
	  exit 1
	fi
}

fn_create() {
	if [ $# -ne 3 ];then
		cat <<EOF
usage:
	./vm_host.sh create <image> <vm_name> <port>
example:
	./vm_host.sh create ubuntu14.04 node1 2222
EOF
		exit 1
	fi

	BASE_IMAGE="_base_image/$1.img"
	BASE_SEED_IMAGE="_image/seed.img"
	VM_NAME=$2
	SSH_PORT=$3
	echo "VM_NAME   : ${VM_NAME}"
	echo "SSH_PORT  : ${SSH_PORT}"
	echo "BASE_IMAGE: ${BASE_IMAGE}"

	echo "##### check base_image: ${BASE_IMAGE} #####"
	if [ ! -s ${BASE_IMAGE} ];then
		echo "base_image: ${BASE_IMAGE} not exist"
		exit 1
	fi

	echo "##### check base_seed_image: ${BASE_SEED_IMAGE} #####"
	if [ ! -s ${BASE_SEED_IMAGE} ];then
		echo "base_seed_image: ${BASE_SEED_IMAGE} not exist"
		exit 1
	fi

	echo "##### check vmName: ${VM_NAME} #####"
	ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | grep "\-name ${VM_NAME}"
	if [ $? -eq 0 ];then
		echo -e "\n[error]vmName ${VM_NAME} is in-used, please change the vm_name"
		exit 1
	fi

	echo "##### check port: ${SSH_PORT} #####"
	netstat -tnopl | grep ":${SSH_PORT} "
	if [ $? -eq 0 ];then
		echo -e "\n[error]port ${SSH_PORT} is in-used, please change the port"
		exit 1
	fi

	echo "##### check the image #####"
	if [ -f _tmp/host/${VM_NAME}.img -o -f _tmp/host/${SSH_PORT} ];then
		echo -e "\n[error]image of ${VM_NAME} is existed, please change the vm_name, or clear the old one"
		exit 1
	fi	

	echo ##### prepare image #####"
	make ${BASE_IMAGE}

	# create ephemeral overlay qcow image
	# (we probably could have used -snapshot)
	
	IMG="_tmp/host/${VM_NAME}.img"
	qemu-img create -f qcow2 -b `pwd`/${BASE_IMAGE} $IMG

	SEED_IMG="_tmp/host/${VM_NAME}-seed.img"
	qemu-img create -f qcow2 -b `pwd`/${BASE_SEED_IMAGE} $SEED_IMG

	echo "##### list images for ${VM_NAME} #####"
	ls _tmp/host/${VM_NAME}*

	sleep 1

	echo -e "\n##### start the VM #####"
	# way1
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME}  -net nic -net user -hda $IMG -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22 &

	#sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME}  -net nic -net user -drive file=${IMG},if=virtio -boot c -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22&
	

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

	SSH_OPT="-p${SSH_PORT} -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	
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

	sleep 5
	# copy a script in (we could use Ansible for this kind of thing, but...)
	echo "start copy test.sh to guest..."
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/test.sh root@localhost:~

	# run the script
	echo "execute test.sh in guest ..."
	ssh ${SSH_OPT} root@localhost ./test.sh

	# TODO run the benchmark

	# shut down the VM
	#ssh ${SSH_OPT} root@localhost sudo shutdown -h now

}

fn_list(){
	if [ $# -ne 0 ];then
		cat <<EOF
usage:
	./vm_host.sh list
EOF
		exit 1
	fi
		
	#output
	echo -e "vmName\tport\tPID\tbacking_image"

	ls _tmp/host/*-seed.img >/dev/null 2>&1
	if [ $? -eq 0 ];then
		cd _tmp/host
		for img in `ls *-seed.img`
		do
			VM_NAME=$(echo $img | cut -f1 -d"-")
			PORT=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/host/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"::22")>0){split($i,p,":");printf "%s\n", p[2]}} }')
			PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/host/" | grep -Ev "(sudo|grep)" | awk '{print $2}' )
			
			HDA_IMG=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/host/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"-hda")>0){print $(i+1) }} }')
			BACKING_FILE=$(qemu-img info `pwd`/../../$HDA_IMG | grep "backing file" | awk 'BEGIN{FS="/"}{print $NF}')

			echo -e "$VM_NAME\t${PORT}\t${PID}\t${BACKING_FILE}"
		done
		cd - > /dev/null
	fi


}

fn_exec(){
	if [[ $# -ne 2 ]] || [[ -z $2 ]] ;then
		cat <<EOF
usage:
	./vm_host.sh exec <vm_name> <command_line>
example:
	./vm_host.sh exec node1 "top -b"
EOF
		exit 1
	fi
	VM_NAME=$1
	CMD_LINE=$2
	SSH_PORT=$(ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | grep "\-name ${VM_NAME}" | awk '{for (i=1;i<=NF;i++){if (index($i,"::22")>0){split($i,p,":");printf "%s\n", p[2]}} }')
	#echo "VM_NAME: ${VM_NAME}"
	#echo "SSH_PORT: ${SSH_PORT}"
	if [ -z ${SSH_PORT} ];then
		echo "can not find vmName: ${VM_NAME}"
		exit 1
	fi

	SSH_OPT="-p${SSH_PORT} -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
	echo "> ssh ${SSH_OPT} root@localhost \"bash -c '${CMD_LINE}'\""
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
	ssh ${SSH_OPT} root@localhost "bash -c '${CMD_LINE}'"
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
}

fn_shutdown(){
	if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./vm_host.sh shutdown <vm_name>
example:
	./vm_host.sh shutdown node1
EOF
		exit 1
	fi
	VM_NAME=$1
	if [[ -f _tmp/host/${VM_NAME}-seed.img ]] || [[ -f _tmp/host/${VM_NAME}.img ]];then
		SSH_PORT=$(ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | grep "\-name ${VM_NAME}" | awk '{for (i=1;i<=NF;i++){if (index($i,"::22")>0){split($i,p,":");printf "%s\n", p[2]}} }')
		echo "SSH_PORT: $SSH_PORT"
		if [ ! -z ${SSH_PORT} ];then
			echo "shutdown running VM: ${VM_NAME}"
			SSH_OPT="-p${SSH_PORT} -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
			ssh ${SSH_OPT} root@localhost "shutdown -h now"
			sleep 2
		else
			echo "VM ${VM_NAME} not running"
		fi
		rm -rf _tmp/host/${VM_NAME}.img
		rm -rf _tmp/host/${VM_NAME}-seed.img		
	fi
	
	#check image again
	if [[ ! -f _tmp/host/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/host/${VM_NAME}.img ]];then
		echo "vm ${VM_NAME} not exist now"
	else
		echo "delete vm ${VM_NAME} failed"
	fi
}

fn_ssh(){
if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./vm_host.sh ssh <vm_name>
example:
	./vm_host.sh ssh node1
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

	SSH_OPT="-p${SSH_PORT} -q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	echo "ssh ${SSH_OPT} root@${GUEST_IP}"
	echo "----------------------------------------------------------------------------------------------------------"
	ssh ${SSH_OPT} root@localhost
	echo -e "Goodbye!"

}

fn_stop(){
	if [ $# -ne 1 ];then
			cat <<EOF
	usage:
		./vm_host.sh stop <vm_name>
	example:
		./vm_host.sh stop node1
EOF
			exit 1
		fi
	VM_NAME=$1

	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/host/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ -z ${PID} ];then
		echo "can not find pid of vmName: ${VM_NAME}"
		exit 1
	fi

	echo "stopping VM: ${VM_NAME}..."
	sudo kill -9 ${PID}
	sleep 1
	echo "---------------------------------------"
	echo "current VM list:"
	echo "---------------------------------------"
	fn_list
}

fn_start(){
	if [ $# -ne 2 ];then
			cat <<EOF
	usage:
		./vm_host.sh start <vm_name> <port>
	example:
		./vm_host.sh start node1 2222
EOF
			exit 1
		fi
	VM_NAME=$1
	SSH_PORT=$2

	#check image
	if [[ ! -f _tmp/host/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/host/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f _tmp/host/${VM_NAME}-seed.img ]] || [[ ! -f _tmp/host/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	#check process
	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/host/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is already running"
		exit 1
	fi

	echo "starting VM: ${VM_NAME}  PORT: ${SSH_PORT}, please wait..."
	IMG="_tmp/host/${VM_NAME}.img"
	SEED_IMG="_tmp/host/${VM_NAME}-seed.img"
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME}  -net nic -net user -hda $IMG -hdb $SEED_IMG -m 1G -nographic -redir :${SSH_PORT}::22 &


}

## main ###################################################
ACTION=$1
case ${ACTION} in
	images)
		cat <<EOF
#support image
   ubuntu14.04
   centos6
   fedora22
   fedora23
   #ubuntu15.10
   #centos7
   #debian8.2
#how to create a new vm
  ./vm_host.sh create ubuntu14.04 node1 2223
EOF
		;;
	list)
		fn_list $2 $3
		;;
	create)
		fn_create $2 $3 $4 #<image> <vmName> <port>
		;;
	exec)
		fn_exec $2 "$3"  #<vmName> <command>
		;;
	ssh)
		fn_ssh $2 $3 #<vmName>
		;;
	stop)
		fn_stop $2 $3 #<vmName>
		;;
	start)
		fn_start $2 $3 #<vmName> <port>
		;;
	shutdown)
		fn_shutdown $2 $3 #<vmName>
		;;
	*)
		fn_show_usage
		;;
esac
