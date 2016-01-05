#!/bin/bash

#!/bin/bash

SELF=./$(basename $0)
sudo pwd
USERNAME="root"

FLAG="$1"
ACTION="$2"

#check flag
case "${FLAG}" in
	swarm|registry|devstack)
		;;
	*)
		echo "flag should be swarm,registry,devstack"
		cat <<EOF
[usage]
  
    ./vm_nat.sh <flag> <action> <options>

[flag]
	swarm
	registry
	devstack
EOF
		exit 1
		;;
esac

TMP_IMG="_tmp/${FLAG}"


echo "read from etc/config"
echo "----------------------------------"
BR=$(grep BR etc/config | cut -d"=" -f2)
NETWORK_PREFIX=$(grep NETWORK_PREFIX etc/config | cut -d"=" -f2)
echo "BR            : ${BR}"
echo "NETWORK_PREFIX: ${NETWORK_PREFIX}"
echo "----------------------------------"

fn_show_usage() {
	if [ $# -ne 3 ];then
		cat <<EOF
[usage]
  
    ${SELF} <flag> <action> <options>

[flag]
	swarm
	registry
	devstack

[example]

    ${SELF} ${FLAG} images
    ${SELF} ${FLAG} create ubuntu14.04 node1 ${NETWORK_PREFIX}.128
    ${SELF} ${FLAG} list
    ${SELF} ${FLAG} exec node1 "top -b"
    ${SELF} ${FLAG} ssh node1
    ${SELF} ${FLAG} scp node1 ./file1 ~/
    ${SELF} ${FLAG} stop node1
    ${SELF} ${FLAG} start node1
    ${SELF} ${FLAG} clone node1 node2
    ${SELF} ${FLAG} shutdown node1

[usage]

# how to create a new vm(dhcp)
    ${SELF} swarm create ubuntu14.04 node1

# how to create a new vm(static ip)
    ${SELF} swarm create ubuntu14.04 node1 ${NETWORK_PREFIX}.128

EOF
	  exit 1
	fi
}

fn_create() {
	if [ $# -lt 2 ];then
		cat <<EOF
[usage]
    ${SELF} <flag> create <image> <vm_name> <ip>
[example]
    ${SELF} ${FLAG} create ubuntu14.04 node1 ${NETWORK_PREFIX}.128
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
	ps -ef | grep qemu-system-x86_64 | grep -Ev "(sudo|grep)" | grep "\-name ${VM_NAME}" | grep "_tmp/${FLAG}/"
	if [ $? -eq 0 ];then
		echo -e "\n[error]vmName ${VM_NAME} is in-used, please change the vm_name"
		exit 1
	fi

	echo "##### check the image #####"
	if [ -f ${TMP_IMG}/${VM_NAME}.img -o -f ${TMP_IMG}/${SSH_PORT} ];then
		echo -e "\n[error]image of ${VM_NAME} is existed, please change the vm_name, or clear the old one"
		exit 1
	fi	

	echo "##### check ip #####"
	arp -n | grep ${STATIC_IP} | grep -v "incomplete"
	if [ $? -eq 0 ];then
		echo "[error] ip($STATIC_IP) is using"
		exit 1
	fi

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
	


	echo ##### prepare image #####"
	make ${BASE_IMAGE}

	# create ephemeral overlay qcow image
	# (we probably could have used -snapshot)
	IMG="${TMP_IMG}/${VM_NAME}.img"
	SEED_IMG="${TMP_IMG}/${VM_NAME}-seed.img"
	CFG_IMG="${TMP_IMG}/${VM_NAME}.cfg"

	echo "##### convert user data into an ISO image #####"
	if [ -z ${STATIC_IP} ];then
		echo "dhcp..."
		cat etc/${FLAG}/user-data.dhcp > etc/user-data
	else
		echo "static ip..."
		case "$1" in
			centos6|centos7|fedora22|fedora23)
				echo "init for centos|fedora"
				sed "s/{STATIC_IP}/${STATIC_IP}/" etc/${FLAG}/user-data.static.centos > etc/user-data
				;;
			ubuntu14.04)
				echo "init for ubuntu"
				sed "s/{STATIC_IP}/${STATIC_IP}/" etc/${FLAG}/user-data.static.ubuntu > etc/user-data	
				;;
			*)
				echo "'user-data' only support ubuntu14.04, fedora22, fedora23 and centos6 now"
				exit 1
				;;
		esac
	fi
	echo IMG_TYPE=$1 > $CFG_IMG # save to cfg
	echo IP=${STATIC_IP} >> $CFG_IMG


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
	ls ${TMP_IMG}/${VM_NAME}*

	sleep 1



	echo -e "\n##### start the VM #####"
	# way1
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

	sleep 15
	echo "start waiting guest ip..."
	cnt=0
	WAIT_IP_TIMEOUT=150
	if [ -z ${STATIC_IP} ];then
		while [[ "${GUEST_IP}" == "" ]]
		do
			if [ $cnt -gt ${WAIT_IP_TIMEOUT} ];then
				echo "Get guest ip timeout, quit!"
				exit 1
			fi
			MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
			GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 
			echo "$cnt:waiting guest dhcp ip of mac(${MAC_ADDR})"
			cnt=$((cnt + 1))
			sleep 1
		done
	else
		while [[ "${GUEST_IP}" != "${STATIC_IP}" ]];
		do
			if [ $cnt -gt ${WAIT_IP_TIMEOUT} ];then
				echo "Get guest ip timeout, quit!"
				exit 1
			fi
			if [ "${STATIC_IP}" != "" ];then
				ping -c2 -W1 ${STATIC_IP}
			fi
			MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
			GUEST_IP=$(sudo arp -n  | grep "${STATIC_IP}.*${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 
			echo "$cnt:waiting guest static ip(${STATIC_IP}) of mac(${MAC_ADDR})"
			cnt=$((cnt + 1))
			sleep 1
		done

	fi

	echo "$cnt:get guest ip of mac(${MAC_ADDR}): ${GUEST_IP}"

	SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "

	# copy a script in (we could use Ansible for this kind of thing, but...)
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./etc/config ${USERNAME}@${GUEST_IP}:~
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/init-${FLAG}.sh ${USERNAME}@${GUEST_IP}:~
	rsync -a -e "ssh ${SSH_OPT} -oConnectionAttempts=60" ./util/set_ip.sh ${USERNAME}@${GUEST_IP}:~

	# run the script
	ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} "./init-${FLAG}.sh"
	case "$1" in
		centos6|centos7|fedora22|fedora23)
			ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} "sed -r -i \"s@HOSTNAME=.*@HOSTNAME=${VM_NAME}@\" /etc/sysconfig/network"
			ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} "service iptables stop"
			;;
	esac

	# TODO run the benchmark

	# shut down the VM
	#ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} sudo shutdown -h now

}

fn_list(){
	if [ $# -ne 0 ];then
		cat <<EOF
[usage]
    ${SELF} ${FLAG} list
EOF
		exit 1
	fi
		
	#output
	echo -e "VMNAME\t\tPID\tMAC_ADDR\t\tCURRENT_IP\tIP_TYPE\tCONFIG_IP\tBACKING_IMAGE"

	ls ${TMP_IMG}/*-seed.img >/dev/null 2>&1
	if [ $? -eq 0 ];then
		cd ${TMP_IMG}
		for img in `ls *-seed.img`
		do
			VM_NAME=$(echo $img | cut -f1 -d"-")
			MAC_ADDR=""
			GUEST_IP=""
			BACKING_FILE=""
			PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print $2}' )
			CFG_IMG="${VM_NAME}.cfg"
			CONFIG_IP=$(grep "IP=" $CFG_IMG | cut -d"=" -f2)
			if [ ! -z ${CONFIG_IP} ];then
				ping -c2 -W1 ${CONFIG_IP} >/dev/null 2>&1
			fi
			if [ ! -z ${PID} ];then
				HDA_IMG=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"-hda")>0){print $(i+1) }} }')
				BACKING_FILE=$(qemu-img info `pwd`/../../$HDA_IMG | grep "backing file" | awk 'BEGIN{FS="/"}{print $NF}')

				MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
				GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

				if [ -z ${GUEST_IP} ];then
					GUEST_IP="???.???.???.???"
				fi
			else
				PID="-----"
				MAC_ADDR="--:--:--:--:--:--"
				GUEST_IP="---.---.---.---"
				BACKING_FILE=$(grep "IMG_TYPE=" $CFG_IMG | cut -d"=" -f2)
			fi
			if [ -z ${CONFIG_IP} ];then
				IP_TYPE="dhcp"
				CONFIG_IP="---.---.---.---"
			else
				IP_TYPE="static"
			fi

			printf "%-16s%s\t%s\t%s\t%s\t%s\t%s\n" $VM_NAME $PID $MAC_ADDR $GUEST_IP $IP_TYPE $CONFIG_IP $BACKING_FILE
		done
		cd - > /dev/null
	fi

}

fn_exec(){
	if [[ $# -ne 2 ]] || [[ -z $2 ]] ;then
		cat <<EOF
[usage]
    ${SELF} <flag> exec <vm_name> <command_line>
[example]
    ${SELF} ${FLAG} exec node1 "top -b"
EOF
		exit 1
	fi
	VM_NAME=$1
	CMD_LINE=$2

	MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
	if [ ! -z ${MAC_ADDR} ];then
		GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 
		SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
		echo "-----------------------------------------------------------------------------------------------------------------------------------------"
		echo "> ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} \"bash -c '${CMD_LINE}'\""
		echo "-----------------------------------------------------------------------------------------------------------------------------------------"
		ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} "bash -c '${CMD_LINE}'"
		echo "-----------------------------------------------------------------------------------------------------------------------------------------"
	else
		echo "vm name '${VM_NAME}' not found"
	fi
}

fn_shutdown(){
	if [ $# -ne 1 ];then
		cat <<EOF
[usage]
    ${SELF} <flag> shutdown <vm_name>
[example]
    ${SELF} ${FLAG} shutdown node1
EOF
		exit 1
	fi
	VM_NAME=$1
	if [[ -f ${TMP_IMG}/${VM_NAME}-seed.img ]] || [[ -f ${TMP_IMG}/${VM_NAME}.img ]];then
		MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
		GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

		if [[ ! -z ${GUEST_IP} ]];then
			echo "shutdown running VM: ${VM_NAME}"
			SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
			ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP} "shutdown -h now"
			sleep 2
		else
			echo "VM ${VM_NAME} not running"
		fi
		rm -rf ${TMP_IMG}/${VM_NAME}.img
		rm -rf ${TMP_IMG}/${VM_NAME}-seed.img
		rm -rf ${TMP_IMG}/${VM_NAME}.cfg
	fi
	
	#check image again
	if [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] && [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "vm ${VM_NAME} not exist now"
	else
		echo "delete vm ${VM_NAME} failed"
	fi

	PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} "  | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print $2}' )
	for p in $PID
	do
		ps -ef | grep " ${p} .*${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk -v p=$p  '{if($2==p){print $0}}'
		sudo kill $p
	done
}

fn_ssh(){
if [ $# -ne 1 ];then
		cat <<EOF
[usage]
    ${SELF} <flag> ssh <vm_name>
[example]
    ${SELF} $FLAG ssh node1
EOF
		exit 1
	fi
	VM_NAME=$1
	
	#echo "VM_NAME: ${VM_NAME}"

	MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
	if  [ ! -z ${MAC_ADDR} ];then
		GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

		SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
		echo "ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP}"
		echo "----------------------------------------------------------------------------------------------------------"
		ssh ${SSH_OPT} ${USERNAME}@${GUEST_IP}
		echo -e "Goodbye!"
	else
		echo "vm name '${VM_NAME}' not found"
	fi

}

fn_scp(){
if [ $# -ne 3 ];then
		cat <<EOF
[usage]
    ${SELF} <flag> scp <vm_name> <srcFile> <targetPath>
[example]
    ${SELF} ${FLAG} scp node1 ./file1 ~/
EOF
		exit 1
	fi
	VM_NAME=$1
	SRC_FILE=$2
	TGT_PATH=$3
	
	#echo "VM_NAME: ${VM_NAME}"

	MAC_ADDR=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" | awk '{print substr($0,49)}' | awk '{for (i=1;i<=NF;i++){if (index($i,"macaddr=")>0){print $(i) }} }' | awk -F"=" '{print $NF}')
	if  [ ! -z ${MAC_ADDR} ];then
		GUEST_IP=$(sudo arp -n  | grep "${MAC_ADDR}" |  grep -v "incomplete" | awk '{print $1}' | head -n 1 ) 

		SSH_OPT="-q -i etc/.ssh/id_rsa -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no "
		echo "scp ${SSH_OPT} ${SRC_FILE} ${USERNAME}@${GUEST_IP}:${TGT_PATH}"
		echo "----------------------------------------------------------------------------------------------------------"
		scp ${SSH_OPT} ${SRC_FILE} ${USERNAME}@${GUEST_IP}:${TGT_PATH}
		echo -e "Done!"
	else
		echo "vm name '${VM_NAME}' not found"
	fi
}


fn_stop(){
	if [ $# -ne 1 ];then
			cat <<EOF
[usage]
    ${SELF} <flag> stop <vm_name>
[example]
    ${SELF} ${FLAG} stop node1
EOF
			exit 1
		fi
	VM_NAME=$1

	PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	#echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ -z ${PID} ];then
		echo "can not find pid of vm name: ${VM_NAME}"
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
[usage]
    ${SELF} <flag> start <vm_name> [ip]
[example]
	${SELF} ${FLAG} start node1 # dhcp
    ${SELF} ${FLAG} start node1 192.168.122.128 #static ip
EOF
			exit 1
	fi
	VM_NAME=$1
	STATIC_IP=$2
	echo "VM_NAME   : ${VM_NAME}"
	echo "STATIC_IP : ${STATIC_IP}"

	#check image
	if [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] && [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] || [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	#check process
	PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is already running"
		exit 1
	fi

	echo "starting VM: ${VM_NAME}, please wait..."
	IMG="${TMP_IMG}/${VM_NAME}.img"
	SEED_IMG="${TMP_IMG}/${VM_NAME}-seed.img"
	CFG_IMG="${TMP_IMG}/${VM_NAME}.cfg" #load from cfg
	IMG_TYPE=$(grep "IMG_TYPE=" $CFG_IMG | cut -d"=" -f2 )

	if [ -z ${STATIC_IP} ];then
		echo "get IP from ${CFG_IMG}..."
		STATIC_IP=$(grep "IP=" ${CFG_IMG} | cut -d"=" -f2)
		echo "found IP : ${STATIC_IP}"
	fi

	echo "##### convert user data into an ISO image #####"
	if [ -z ${STATIC_IP} ];then
		echo "no old ip, no ip specified, so use dhcp..."
		cat etc/${FLAG}/user-data.dhcp > etc/user-data
	else
		echo "static ip..."
		case "${IMG_TYPE}" in
			centos6|centos7|fedora22|fedora23)
				echo "init for centos|fedora"
				sed "s/{STATIC_IP}/${STATIC_IP}/" etc/${FLAG}/user-data.static.centos > etc/user-data
				;;
			ubuntu14.04)
				echo "init for ubuntu"
				sed "s/{STATIC_IP}/${STATIC_IP}/" etc/${FLAG}/user-data.static.ubuntu > etc/user-data	
				;;
			*)
				echo "'user-data' only support ubuntu14.04, fedora22, fedora23 and centos6 now"
				exit 1
				;;
		esac
	fi
	if [ ! -z ${STATIC_IP} ];then
		sed -r -i "s:IP=.*:IP=${STATIC_IP}:" ${CFG_IMG}
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


	MAC=$(hexdump -n3 -e'/3 "52:54:00" 3/1 ":%02X"' /dev/random | tr '[A-Z]' '[a-z]')
	sudo qemu-system-x86_64 -enable-kvm -name ${VM_NAME} -net nic,model=virtio,macaddr=${MAC} -net bridge,br=${BR} -hda ${IMG} -hdb $SEED_IMG -m 1G -nographic &

}

fn_clone(){

	if [ $# -ne 2 ];then
			cat <<EOF
[usage]
    ${SELF} <flag> clone <source_vm_name> <target_vm_name>
[example]
    ${SELF} ${FLAG} clone node1 node2
EOF
			exit 1
		fi
	VM_NAME=$1
	NEW_VM_NAME=$2

	echo "check image for ${VM_NAME}: should be exist"
	#check image
	if [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] && [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] || [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	echo "check image for ${NEW_VM_NAME}: should not be exist"
	#check image
	if [[ -f ${TMP_IMG}/${NEW_VM_NAME}-seed.img ]] || [[ -f ${TMP_IMG}/${NEW_VM_NAME}.img ]];then
		echo "[error]image of VM ${NEW_VM_NAME} already exist"
		exit 1
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, OK"
	fi

	#check process
	PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is running, please stop it fisrt"
		echo "  ${SELF} stop ${VM_NAME}"
		exit 1
	fi

	echo "start clone image of VM: ${VM_NAME} -> ${NEW_VM_NAME}, please wait..."
	IMG="${TMP_IMG}/${VM_NAME}.img"
	SEED_IMG="${TMP_IMG}/${VM_NAME}-seed.img"
	CFG_IMG="${TMP_IMG}/${VM_NAME}.cfg"

	NEW_IMG="${TMP_IMG}/${NEW_VM_NAME}.img"
	NEW_SEED_IMG="${TMP_IMG}/${NEW_VM_NAME}-seed.img"
	NEW_CFG_IMG="${TMP_IMG}/${NEW_VM_NAME}.cfg"

	cp ${IMG} ${NEW_IMG}
	cp ${SEED_IMG} ${NEW_SEED_IMG}
	cp ${CFG_IMG} ${NEW_CFG_IMG}

	grep IMG_TYPE ${CFG_IMG} > $NEW_CFG_IMG # save to cfg
	echo IP="" >> $NEW_CFG_IMG


	if [[ -f ${TMP_IMG}/${NEW_VM_NAME}-seed.img ]] && [[ -f ${TMP_IMG}/${NEW_VM_NAME}.img ]] && [[ -f ${CFG_IMG}/${NEW_CFG_IMG}.img ]];then
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
[usage]
    ${SELF} <flag> clone <source_vm_name> <target_vm_name>
[example]
    ${SELF} ${FLAG} clone node1 node2
EOF
			exit 1
		fi
	VM_NAME=$1
	NEW_VM_NAME=$2

	echo "check image for ${VM_NAME}: should be exist"
	#check image
	if [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] && [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} doesn't exist"
		exit 1
	elif [[ ! -f ${TMP_IMG}/${VM_NAME}-seed.img ]] || [[ ! -f ${TMP_IMG}/${VM_NAME}.img ]];then
		echo "[error]image of VM ${VM_NAME} was damaged "
		exit 1
	else
		echo "image of VM ${VM_NAME} is OK"
	fi

	echo "check image for ${NEW_VM_NAME}: should not be exist"
	#check image
	if [[ -f ${TMP_IMG}/${NEW_VM_NAME}-seed.img ]] || [[ -f ${TMP_IMG}/${NEW_VM_NAME}.img ]];then
		echo "[error]image of VM ${NEW_VM_NAME} already exist"
		exit 1
	else
		echo "image of VM ${NEW_VM_NAME} doesn't existed, OK"
	fi

	#check process
	PID=$(ps -ef | grep "qemu-system-x86_64.*\-name ${VM_NAME} " | grep "${TMP_IMG}/" | grep -Ev "(sudo|grep)" |awk '{print $2}')
	echo "VM_NAME: ${VM_NAME}"
	echo "PID: ${PID}"
	if [ ! -z ${PID} ];then
		echo "vmName: ${VM_NAME} is running, please stop it fisrt"
		echo "  ${SELF} stop ${VM_NAME}"
		exit 1
	fi

	echo "start clone image of VM: ${VM_NAME} -> ${NEW_VM_NAME}, please wait..."
	IMG="${TMP_IMG}/${VM_NAME}.img"
	SEED_IMG="${TMP_IMG}/${VM_NAME}-seed.img"
	NEW_IMG="${TMP_IMG}/${NEW_VM_NAME}.img"
	NEW_SEED_IMG="${TMP_IMG}/${NEW_VM_NAME}-seed.img"
	
	cp ${IMG} ${NEW_IMG}
	cp ${SEED_IMG} ${NEW_SEED_IMG}

	if [[ -f ${TMP_IMG}/${NEW_VM_NAME}-seed.img ]] && [[ -f ${TMP_IMG}/${NEW_VM_NAME}.img ]];then
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

if [ ! -d ${TMP_IMG} ];then
	mkdir -p ${TMP_IMG}
fi


ACTION="$2"
#check action
case ${ACTION} in
	images)
		cat <<EOF
[support images]

    ubuntu14.04
    centos7
    centos6
    fedora22
    fedora23

# how to get an image

    make <image_name>
    eg:make ubuntu14.04

EOF
		;;
	list)
		fn_list
		;;
	create)
		fn_create $3 $4 $5 #<image> <vmName> <ip>
		;;
	exec)
		fn_exec $3 "$4"  #<vmName> <command>
		;;
	ssh)
		fn_ssh $3 $4 #<vmName>
		;;
	stop)
		fn_stop $3 $4 #<vmName>
		;;
	start)
		fn_start $3 "$4" #<vmName> <ip>
		;;
	shutdown)
		fn_shutdown $3 $4 #<vmName>
		;;
	clone)
		fn_clone $3 $4 #<sourceVmName> <targetVMName>
		;;
	set_ip)
		fn_set_ip $3 $4 #<vmName> <new_ip>
		;;
	scp)
		fn_scp $3 $4 $5 #<vmName> <srcFile> <targetPath>
		;;
	*)
		fn_show_usage
		;;
esac


