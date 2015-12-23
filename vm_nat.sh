#!/bin/bash

BR="virbr0"
NETWORK_PREFIX="192.168.122"

#BR="br0"
#NETWORK_PREFIX="192.168.1"


fn_show_usage() {
	if [ $# -ne 2 ];then
		cat <<EOF
usage:
	./vm-nat.sh <action> <option>
example: 
	./vm-nat.sh images
	./vm-nat.sh create ubuntu14.04 node1 ${NETWORK_PREFIX}.128
	./vm-nat.sh list
	./vm-nat.sh exec node1 "top -b"
	./vm-nat.sh ssh node1
	./vm-nat.sh stop node1
	./vm-nat.sh start node1
	./vm-nat.sh shutdown node1

EOF
	  exit 1
	fi
}

fn_create() {
	if [ $# -lt 2 ];then
		cat <<EOF
usage:
	./vm-nat.sh create <image> <vm_name> <ip>
example:
	./vm-nat.sh create ubuntu14.04 node1 ${NETWORK_PREFIX}.128
EOF
		exit 1
	fi

	BASE_IMAGE="_base_image/$1.img"
	VM_NAME=$2
	STATIC_IP=$3
	echo "VM_NAME   : ${VM_NAME}"
	echo "BASE_IMAGE: ${BASE_IMAGE}"
	echo "STATIC_IP : ${STATIC_IP}"

	echo "##### check base_image: ${BASE_IMAGE} #####"
	if [ ! -s ${BASE_IMAGE} ];then
		echo "base_image: ${BASE_IMAGE} not exist"
		exit 1
	fi

	echo "##### check vmName: ${VM_NAME} #####"
	ps -au | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | grep "\-name ${VM_NAME}"
	if [ $? -eq 0 ];then
		echo -e "\n[error]vmName ${VM_NAME} is in-used, please change the vm_name"
		exit 1
	fi

	echo "##### check the image #####"
	if [ -f _tmp/nat/${VM_NAME}.img -o -f _tmp/nat/${SSH_PORT} ];then
		echo -e "\n[error]image of ${VM_NAME} is existed, please change the vm_name, or clear the old one"
		exit 1
	fi	

	echo "##### check ip #####"
	arp | grep ${STATIC_IP} | grep -v "incomplete"
	if [ $? -eq 0 ];then
		echo "[error] ip($STATIC_IP) is using"
		exit 1
	fi
	
	echo ##### prepare image #####"
	make ${BASE_IMAGE}

	# create ephemeral overlay qcow image
	# (we probably could have used -snapshot)
	IMG="_tmp/nat/${VM_NAME}.img"
	SEED_IMG="_tmp/nat/${VM_NAME}-seed.img"

	echo "##### convert user data into an ISO image #####"
	if [ -z ${STATIC_IP} ];then
		echo "dhcp..."
		cat etc/user-data.dhcp > etc/user-data
	else
		echo "static ip..."
		sed "s/{STATIC_IP}/${STATIC_IP}/" etc/user-data.static > etc/user-data
	fi

	echo "##### change hostname #####"
	sed -i "s/{HOSTNAME}/${VM_NAME}/" etc/user-data

	echo "##### change network prefix #####"
	sed -i "s/{NETWORK_PREFIX}/${NETWORK_PREFIX}/" etc/user-data	

	echo "etc/user-data"
	echo "-----------------------------------"
	cat etc/user-data
	echo "-----------------------------------"
	echo "##### generate seed.img: ${SEED_IMG} #####"	
	cloud-localds ${SEED_IMG} etc/user-data

	if [ -f ${SEED_IMG} ];then
		echo "${SEED_IMG} generate succeed"
	else
		echo "${SEED_IMG} generate failed"
		exit 1
	fi

	echo "##### generate image from base_image #####"
	qemu-img create -f qcow2 -b `pwd`/${BASE_IMAGE} $IMG


	echo "##### list images for ${VM_NAME} #####"
	ls _tmp/nat/${VM_NAME}*

	sleep 1

	echo "##### check bridge: ${BR} #####"
	
	ip addr | grep  " ${BR}:" 
	if [ $? -ne 0 ];then
		echo "bridge device ${BR} not found"
		exit 1
	fi

	if [ ! -f /etc/qemu/bridge.conf ];then
		cat <<EOF
	/etc/qemu/bridge.conf not found, please create it first
	$ sudo -s
	# echo 'allow `echo ${BR}`' > /etc/qemu/bridge.conf
EOF
		exit 1
	fi

	grep "allow ${BR}" /etc/qemu/bridge.conf
	if [ $? -ne 0 ];then
		cat <<EOF
	${BR} not allow in /etc/qemu/bridge.conf, please run the following command first:
	$ sudo -s
	# echo 'allow `echo ${BR}`' > /etc/qemu/bridge.conf
EOF
		exit 1
	fi

	echo "bridge ${BR} is available"
	echo "##### generate mac address#####"
	MAC=$(hexdump -n3 -e'/3 "52:54:00" 3/1 ":%02X"' /dev/random | tr '[A-Z]' '[a-z]')
	
	echo -e "\n##### start the VM #####"
	# way1
	sudo pwd
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME} -net nic,model=virtio,macaddr=${MAC} -net bridge,br=${BR} -hda ${IMG} -hdb $SEED_IMG -m 1G -nographic &

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

	sleep 10
	echo "start waiting guest ip..."
	cnt=0
	if [ -z ${STATIC_IP} ];then
		while [[ "${GUEST_IP}" == "" ]]
		do
			if [ $cnt -gt 10 ];then
				echo "Get guest ip timeout, quit!"
				exit 1
			fi
			MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
			GUEST_IP=$(sudo arp  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 
			echo "$cnt:waiting guest ip of mac(${MAC_ADDR})"
			cnt=$((cnt + 1))
			sleep 1
		done
	else
		while [[ "${GUEST_IP}" != "${STATIC_IP}" ]];
		do
			if [ $cnt -gt 10 ];then
				echo "Get guest ip timeout, quit!"
				exit 1
			fi
			MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
			GUEST_IP=$(sudo arp  | grep "${STATIC_IP}.*${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 
			echo "$cnt:waiting guest ip(${STATIC_IP}) of mac(${MAC_ADDR})"
			cnt=$((cnt + 1))
			sleep 1
		done

	fi

	echo "$cnt:get guest ip of mac(${MAC_ADDR}): ${GUEST_IP}"

	SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

	# copy a script in (we could use Ansible for this kind of thing, but...)
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/init.sh root@${GUEST_IP}:~
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/set_ip.sh root@${GUEST_IP}:~

	# run the script
	ssh ${SSH_OPT} root@${GUEST_IP} "./init.sh"

	# TODO run the benchmark

	# shut down the VM
	#ssh ${SSH_OPT} root@${GUEST_IP} sudo shutdown -h now

}

fn_list(){
	if [ $# -ne 0 ];then
		cat <<EOF
usage:
	./vm-nat.sh list
EOF
		exit 1
	fi
		
	#output
	echo -e "vmName\tPID\tmac_addr\t\tguest_ip\tbacking_image"

	ls _tmp/nat/*-seed.img >/dev/null 2>&1
	if [ $? -eq 0 ];then
		cd _tmp/nat
		for img in `ls *-seed.img`
		do
			VM_NAME=$(echo $img | cut -f1 -d"-")
			MAC_ADDR=""
			GUEST_IP=""
			BACKING_FILE=""
			PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print $2}' )
			if [ ! -z ${PID} ];then
				HDA_IMG=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"-hda")>0){print $(i+1) }} }')
				BACKING_FILE=$(qemu-img info `pwd`/../../$HDA_IMG | grep "backing file" | awk 'BEGIN{FS="/"}{print $NF}')

				MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
				GUEST_IP=$(sudo arp  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

				if [ -z ${GUEST_IP} ];then
					GUEST_IP="               "
				fi
			fi
			echo -e "$VM_NAME\t${PID}\t${MAC_ADDR}\t${GUEST_IP}\t${BACKING_FILE}"
		done
		cd - > /dev/null
	fi

}

fn_exec(){
	if [[ $# -ne 2 ]] || [[ -z $2 ]] ;then
		cat <<EOF
usage:
	./vm-nat.sh exec <vm_name> <command_line>
example:
	./vm-nat.sh exec node1 "top -b"
EOF
		exit 1
	fi
	VM_NAME=$1
	CMD_LINE=$2

	MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
	GUEST_IP=$(sudo arp  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

	SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
	echo "> ssh ${SSH_OPT} root@${GUEST_IP} \"bash -c '${CMD_LINE}'\""
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
	ssh ${SSH_OPT} root@${GUEST_IP} "bash -c '${CMD_LINE}'"
	echo "-----------------------------------------------------------------------------------------------------------------------------------------"
}

fn_shutdown(){
	if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./vm-nat.sh shutdown <vm_name>
example:
	./vm-nat.sh shutdown node1
EOF
		exit 1
	fi
	VM_NAME=$1
	if [[ -f _tmp/nat/${VM_NAME}-seed.img ]] || [[ -f _tmp/nat/${VM_NAME}.img ]];then
		MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
		GUEST_IP=$(sudo arp  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

		if [[ ! -z ${GUEST_IP} ]];then
			echo "shutdown running VM: ${VM_NAME}"
			SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
			ssh ${SSH_OPT} root@${GUEST_IP} "shutdown -h now"
			sleep 2
		else
			echo "VM ${VM_NAME} not running"
		fi
		rm -rf _tmp/nat/${VM_NAME}.img
		rm -rf _tmp/nat/${VM_NAME}-seed.img		
	fi
	
	#check image again
	if [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "vm ${VM_NAME} not exist now"
	else
		echo "delete vm ${VM_NAME} failed"
	fi

	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}"  | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print $2}' )
	for p in $PID
	do
		ps -au | grep " ${p} .*_tmp/nat/" | grep -Ev "(sudo|grep)" | awk -v p=$p  '{if($2==p){print $0}}'
		sudo kill $p
	done
}

fn_ssh(){
if [ $# -ne 1 ];then
		cat <<EOF
usage:
	./vm-nat.sh ssh <vm_name>
example:
	./vm-nat.sh ssh node1
EOF
		exit 1
	fi
	VM_NAME=$1
	echo "VM_NAME: ${VM_NAME}"

	MAC_ADDR=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,66)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
	GUEST_IP=$(sudo arp  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

	SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
	echo "ssh ${SSH_OPT} root@${GUEST_IP}"
	echo "----------------------------------------------------------------------------------------------------------"
	ssh ${SSH_OPT} root@${GUEST_IP}
	echo -e "Goodbye!"

}

fn_stop(){
	if [ $# -ne 1 ];then
			cat <<EOF
	usage:
		./vm-nat.sh stop <vm_name>
	example:
		./vm-nat.sh stop node1
EOF
			exit 1
		fi
	VM_NAME=$1

	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
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
	if [ $# -ne 1 ];then
			cat <<EOF
	usage:
		./vm-nat.sh start <vm_name>
	example:
		./vm-nat.sh start node1
EOF
			exit 1
		fi
	VM_NAME=$1

	#check image
	if [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] || [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	#check process
	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is already running"
		exit 1
	fi

	echo "starting VM: ${VM_NAME}, please wait..."
	IMG="_tmp/nat/${VM_NAME}.img"
	SEED_IMG="_tmp/nat/${VM_NAME}-seed.img"

	MAC=$(hexdump -n3 -e'/3 "52:54:00" 3/1 ":%02X"' /dev/random | tr '[A-Z]' '[a-z]')
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME} -net nic,model=virtio,macaddr=${MAC} -net bridge,br=${BR} -hda ${IMG} -hdb $SEED_IMG -m 1G -nographic &

}

fn_clone(){

	if [ $# -ne 2 ];then
			cat <<EOF
	usage:
		./vm-nat.sh clone <source_vm_name> <target_vm_name>
	example:
		./vm-nat.sh clone node1 node2
EOF
			exit 1
		fi
	VM_NAME=$1
	NEW_VM_NAME=$2

	echo "check image for ${VM_NAME}: should be exist"
	#check image
	if [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] || [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	echo "check image for ${NEW_VM_NAME}: should not be exist"
	#check image
	if [[ -f _tmp/nat/${NEW_VM_NAME}-seed.img ]] || [[ -f _tmp/nat/${NEW_VM_NAME}.img ]];then
		echo "[error]image of VM ${NEW_VM_NAME} already exist"
		exit 1
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, OK"
	fi

	#check process
	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is running, please stop it fisrt"
		echo "  ./vm_nat.sh stop ${VM_NAME}"
		exit 1
	fi

	echo "start clone image of VM: ${VM_NAME} -> ${NEW_VM_NAME}, please wait..."
	IMG="_tmp/nat/${VM_NAME}.img"
	SEED_IMG="_tmp/nat/${VM_NAME}-seed.img"
	NEW_IMG="_tmp/nat/${NEW_VM_NAME}.img"
	NEW_SEED_IMG="_tmp/nat/${NEW_VM_NAME}-seed.img"
	
	cp ${IMG} ${NEW_IMG}
	cp ${SEED_IMG} ${NEW_SEED_IMG}

	if [[ -f _tmp/nat/${NEW_VM_NAME}-seed.img ]] && [[ -f _tmp/nat/${NEW_VM_NAME}.img ]];then
		echo "clone ${VM_NAME} to ${NEW_VM_NAME} succeed!"
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, clone failed"
	fi

	echo "---------------------------------------"
	echo "current VM list:"
	echo "---------------------------------------"
	fn_list
}


fn_set_ip(){

	if [ $# -ne 2 ];then
			cat <<EOF
	usage:
		./vm-nat.sh clone <source_vm_name> <target_vm_name>
	example:
		./vm-nat.sh clone node1 node2
EOF
			exit 1
		fi
	VM_NAME=$1
	NEW_VM_NAME=$2

	echo "check image for ${VM_NAME}: should be exist"
	#check image
	if [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] && [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f _tmp/nat/${VM_NAME}-seed.img ]] || [[ ! -f _tmp/nat/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	echo "check image for ${NEW_VM_NAME}: should not be exist"
	#check image
	if [[ -f _tmp/nat/${NEW_VM_NAME}-seed.img ]] || [[ -f _tmp/nat/${NEW_VM_NAME}.img ]];then
		echo "[error]image of VM ${NEW_VM_NAME} already exist"
		exit 1
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, OK"
	fi

	#check process
	PID=$(ps -au | grep "qemu-system-x86_64.*\-name ${VM_NAME}" | grep "_tmp/nat/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is running, please stop it fisrt"
		echo "  ./vm_nat.sh stop ${VM_NAME}"
		exit 1
	fi

	echo "start clone image of VM: ${VM_NAME} -> ${NEW_VM_NAME}, please wait..."
	IMG="_tmp/nat/${VM_NAME}.img"
	SEED_IMG="_tmp/nat/${VM_NAME}-seed.img"
	NEW_IMG="_tmp/nat/${NEW_VM_NAME}.img"
	NEW_SEED_IMG="_tmp/nat/${NEW_VM_NAME}-seed.img"
	
	cp ${IMG} ${NEW_IMG}
	cp ${SEED_IMG} ${NEW_SEED_IMG}

	if [[ -f _tmp/nat/${NEW_VM_NAME}-seed.img ]] && [[ -f _tmp/nat/${NEW_VM_NAME}.img ]];then
		echo "clone ${VM_NAME} to ${NEW_VM_NAME} succeed!"
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, clone failed"
	fi

	echo "---------------------------------------"
	echo "current VM list:"
	echo "---------------------------------------"
	fn_list
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
  ./vm-nat.sh create ubuntu14.04 node1 2223
EOF
		;;
	list)
		fn_list $2 $3
		;;
	create)
		fn_create $2 $3 $4 #<image> <vmName> <ip>
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
	clone)
		fn_clone $2 $3 #<sourceVmName> <targetVMName>
		;;
	set_ip)
		fn_set_ip $2 $3 #<vmName> <new_ip>
		;;
	*)
		fn_show_usage
		;;
esac
