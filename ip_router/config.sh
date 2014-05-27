#!/bin/bash
# The configure a DREAMER node - after running setup.sh included in DREAMER package

echo -e "\n"
echo "#############################################################"
echo "##           DREAMER IP/SDN Hyibrid node config            ##"
echo "##                                                         ##"
echo "## The configuration process can last many minutes. Please ##"
echo "## and do not interrupt the process.                       ##"
echo "#############################################################"

#temporaneamente...
TUNL_BRIDGE=br-tun
TYPE_OF_TUNNEL="vxlan"
#TYPE_OF_TUNNEL="openvpn"
# with openvpn tunnel you have to modify testbed.sh

plain_ip_router_vxlan_2 () {
	
	create_vxlan_interfaces
	ovs-vsctl add-br $TUNL_BRIDGE
	echo -e "\n-Adding interfaces to bridge $TUNL_BRIDGE"
	
	for i in ${TAP[@]}; do
		eval remoteport=\${${i}[1]}
		eval remoteaddr=\${!$i[2]}
		ovs-vsctl add-port $TUNL_BRIDGE  $i -- set Interface $i type=vxlan options:remote_ip=$remoteaddr options:dst_port=$remoteport
	done

	echo -e "\n-Adding internal virtual interfaces to bridge $TUNL_BRIDGE"
	for i in ${QUAGGAINT[@]}; do
		ovs-vsctl add-port $TUNL_BRIDGE $i -- set Interface $i type=internal
	done
	declare -a ofporttap &&
	declare -a ofportquaggaint &&

	for i in ${TAP[@]}; do
	    OFPORTSTAP[${#OFPORTSTAP[@]}]=$(ovs-vsctl find Interface name=$i | grep -m 1 ofport | awk -F':' '{print $2}' | awk '{ gsub (" ", "", $0); print}')
	done

	for i in ${QUAGGAINT[@]}; do
		OFPORTSQUAGGAINT[${#OFPORTSQUAGGAINT[@]}]=$(ovs-vsctl find Interface name=$i | grep -m 1 ofport | awk -F':' '{print $2}' | awk '{ gsub (" ", "", $0); print}')
	done
	for (( i=0; i<${#OFPORTSTAP[@]}; i++ )); do
	        ovs-ofctl add-flow $TUNL_BRIDGE hard_timeout=0,priority=300,in_port=${OFPORTSTAP[$i]},action=output:${OFPORTSQUAGGAINT[$i]}
	        ovs-ofctl add-flow $TUNL_BRIDGE hard_timeout=0,priority=300,in_port=${OFPORTSQUAGGAINT[$i]},action=output:${OFPORTSTAP[$i]}
	done
}


plain_ip_router_vxlan () {
	
	ii=0
	for j in ${INTERFACES[@]}; do
		
		create_vxlan_bridge

		echo -e "\n-Adding interfaces to bridge $TUNL_BRIDGE-$j"
		
		#TODO: solo le tap che stanno su quella eth 

		for i in ${TAP[@]}; do
    		eval remoteport=\${${i}[1]}
			eval remoteaddr=\${!$i[2]}
			ovs-vsctl add-port $TUNL_BRIDGE-$j  $i -- set Interface $i type=vxlan options:remote_ip=$remoteaddr options:dst_port=$remoteport
		done


		echo -e "\n-Adding internal virtual interfaces to bridge $TUNL_BRIDGE-$j"
		for i in ${QUAGGAINT[@]}; do
			ovs-vsctl add-port $TUNL_BRIDGE-$j $i -- set Interface $i type=internal
		done
		declare -a ofporttap &&
		declare -a ofportquaggaint &&

		for i in ${TAP[@]}; do
		    OFPORTSTAP[${#OFPORTSTAP[@]}]=$(ovs-vsctl find Interface name=$i | grep -m 1 ofport | awk -F':' '{print $2}' | awk '{ gsub (" ", "", $0); print}')
		done

		for i in ${QUAGGAINT[@]}; do
			OFPORTSQUAGGAINT[${#OFPORTSQUAGGAINT[@]}]=$(ovs-vsctl find Interface name=$i | grep -m 1 ofport | awk -F':' '{print $2}' | awk '{ gsub (" ", "", $0); print}')
		done
		for (( i=0; i<${#OFPORTSTAP[@]}; i++ )); do
		        ovs-ofctl add-flow $TUNL_BRIDGE-$j hard_timeout=0,priority=300,in_port=${OFPORTSTAP[$i]},action=output:${OFPORTSQUAGGAINT[$i]}
		        ovs-ofctl add-flow $TUNL_BRIDGE-$j hard_timeout=0,priority=300,in_port=${OFPORTSQUAGGAINT[$i]},action=output:${OFPORTSTAP[$i]}
		done

		ii=$((ii+1))
	done
}


create_vxlan_interfaces () {

	ii=0
	for j in ${INTERFACES[@]}; do
		eval interface_ip=\${${j}[0]}
		eval interface_netmask=\${${j}[1]}
		ip link set ${INTERFACES[$ii]} up
		vconfig add ${INTERFACES[$ii]} $SLICEVLAN
		ip link set ${INTERFACES[$ii]}.$SLICEVLAN up
		ifconfig $j.$SLICEVLAN $interface_ip netmask $interface_netmask
		ip r d 192.168.0.0/16 dev $j.$SLICEVLAN 
		ii=$((ii+1))
	done

	# set static routes
    declare -a ENDIPS
    for i in ${TAP[@]}; do
            eval ELEMENT=\${${i}[2]}
            if [ $(echo ${ENDIPS[@]} | grep -o $ELEMENT | wc -w) -eq 0 ];then
                    ENDIPS[${#ENDIPS[@]}]=$ELEMENT
            fi
    done
    for (( i=0; i<${#ENDIPS[@]}; i++ )); do
            eval remoteaddr=\${${ENDIPS[$i]}[0]}
            eval interface=\${${ENDIPS[$i]}[1]}
            ip r a $remoteaddr dev $interface.$SLICEVLAN  
    done

}


create_vxlan_bridge () {

	ii=0
	for j in ${INTERFACES[@]}; do
		echo -e "\n-Creating OpenVSwitch bridge $TUNL_BRIDGE-$j"

		eval interface_ip=\${${j}[0]}
		eval interface_netmask=\${${j}[1]}
		ip link set ${INTERFACES[$ii]} up
		vconfig add ${INTERFACES[$ii]} $SLICEVLAN
		ip link set ${INTERFACES[$ii]}.$SLICEVLAN up
		ovs-vsctl add-br $TUNL_BRIDGE-$j
		ovs-vsctl add-port  $TUNL_BRIDGE-$j ${INTERFACES[$ii]}.$SLICEVLAN
		ifconfig $TUNL_BRIDGE-$j $interface_ip netmask $interface_netmask
	#	ifconfig $TUNL_BRIDGE-$i 0
		ip r d 192.168.0.0/16 dev $TUNL_BRIDGE-$j 
		ii=$((ii+1))
	done

	# set static routes
    declare -a ENDIPS
    for i in ${TAP[@]}; do
            eval ELEMENT=\${${i}[2]}
            if [ $(echo ${ENDIPS[@]} | grep -o $ELEMENT | wc -w) -eq 0 ];then
                    ENDIPS[${#ENDIPS[@]}]=$ELEMENT
            fi
    done
    for (( i=0; i<${#ENDIPS[@]}; i++ )); do
            eval remoteaddr=\${${ENDIPS[$i]}[0]}
            eval interface=\${${ENDIPS[$i]}[1]}
            ip r a $remoteaddr dev $TUNL_BRIDGE-$interface  
    done

}


echo -e "\n-Looking for a valid configuration file..."
echo -e "---> Looking for configuration file in current directory ($(pwd))..."
if [ -f testbed.sh ];
	then
		# If cfg file is present in current folder, use it
		echo "---> File found in $(pwd). Using local configuration file testbed.sh"
		source testbed.sh
	else
		# If cfg file is not present in current folder, try to look into /etc/dreamer
		echo -e "--> Local configuration file not found in $(pwd).\n---> Looking for configuration file in /etc/dreamer..."
		if [ -f /etc/dreamer/testbed.sh ];
			then
				# If file is present in /etc/dreamer use it
				echo "---> File found in /etc/dreamer. Using local configuration file testbed.sh"
				source /etc/dreamer/testbed.sh
			else
				# If file is not present both in current directory and into /etc/dreamer, try to look for a remote.cfg file in current directory and read from
				# it the variable dreamerconfigserver (link to the file on internet - http)
				echo -e "--> Local configuration file not found in /etc/dreamer.\n---> Looking online for an updated configuration file. Looking for a remote.cfg file in current directory ($(pwd))..."
				if [ -f /etc/dreamer/remote.cfg ];
					then
						echo -e "\n---> remote.cfg file found in /etc/dreamer. Trying to read the file... "
						source /etc/dreamer/remote.cfg
						if [ -n "$DREAMERCONFIGSERVER" ];
							then
								echo -e "---> DREAMERCONFIGSERVER variable found in remote.cfg. Trying to download the configuration file from $DREAMERCONFIGSERVER"
								wget $DREAMERCONFIGSERVER 2> /dev/null
								if [ -f testbed.sh  ];
									then
										# Get the management IP address (IPv4 set on eth0)
										MNGMTADDR=$(ifconfig eth0 | grep -e "inet addr" | awk '{split($0,a," "); print a[2]}' | awk '{split($0,a,":"); print a[2]}')
										wget -O- -q $DREAMERCONFIGSERVER | awk ' /'"# $MNGMTADDR - start"'/ {flag=1;next} /'"# $MNGMTADDR - end"'/{flag=0} flag { print }' /dev/stdin > /etc/dreamer/testbed.sh
										source testbed.sh
										echo "---> Configuration file downloaded in /etc/dreamer."
									else
										echo "---> ERROR: No configuration files found at $DREAMERCONFIGSERVER. Try to upload the file again and make sure that the path is still available."
										EXIT_ERROR=-1
										exit $EXIT_ERROR
								fi
							else
								echo -e "---> ERROR: DREAMERCONFIGSERVER variable not found in remote.cfg file or value not correct. Please, try to correct the value."
								EXIT_ERROR=-1
								exit $EXIT_ERROR
						fi
					else
						echo -e "\n---> ERROR: remote.cfg file not found in /etc/draemer."
						echo -e "\n\n---> ERROR: no configuration files found. Please set either a local or a remote configuration file before starting."
						EXIT_ERROR=-1
                        exit $EXIT_ERROR
				fi
		fi
fi

# Check addresses
echo -e "\n-Checking addresses compatibilities between testbed mgmt network and chosen addresses"
MGMTADDR=$(ifconfig eth0 | grep "inet addr" | awk -F' ' '{print $2}' | awk -F':' '{print $2}')
MGMTMASK=$(ifconfig eth0 | grep "inet addr" | awk -F' ' '{print $4}' | awk -F':' '{print $2}')
MGMTNETWORK=$(ipcalc $MGMTADDR $MGMTMASK | grep Network | awk '{split($0,a," "); print a[2]}')
for (( i=0; i<${#INTERFACES[@]}; i++ )); do
        eval addr=\${${INTERFACES[$i]}[0]}
        eval netmask=\${${INTERFACES[$i]}[1]}
        CURRENTNET=$(ipcalc $addr $netmask | grep Network | awk '{split($0,a," "); print a[2]}')
        if [ $CURRENTNET == $MGMTNETWORK ]
                then
                        echo -e "\nERROR: IP addresses used in testbed.sh conflict with management network. Please choouse other adresses."
                        EXIT_ERROR=-1
                        exit $EXIT_ERROR
        fi
done
for i in ${QUAGGAINT[@]}; do
        eval QUAGGAIP=\${${i}[0]}
        CURRENTNET=$(ipcalc $QUAGGAIP | grep Network | awk '{split($0,a," "); print a[2]}')
        if [ $CURRENTNET == $MGMTNETWORK ]
                then
                        echo -e "\nERROR: IP addresses used in testbed.sh conflict with management network. Please choouse other adresses."
                        EXIT_ERROR=-1
                        exit $EXIT_ERROR
        fi
done

if [ "$TYPE_OF_TUNNEL" = "openvpn" ]; then

echo -e "\n-Setting up physical interfaces"
# deleting white spaces in /etc/network/interfaces
sed -i -e '/^$/d' /etc/network/interfaces &&
# deleting lines related to the interfaces involved in /etc/network/interfaces
for i in ${INTERFACES[@]}; do
	sed -i '/'$i'/d' /etc/network/interfaces
done
# adding configuration for interfaces into /etc/network/interfaces
for i in ${INTERFACES[@]}; do
echo "
auto ${i}
iface ${i} inet manual
up ifconfig ${i} up" >> /etc/network/interfaces
done

# adding configuration for vlan interfaces into /etc/network/interfaces
echo -e "\n-Setting VLAN ${slicevlan} on interfaces"
for (( i=0; i<${#INTERFACES[@]}; i++ )); do
	eval addr=\${${INTERFACES[$i]}[0]}
	eval netmask=\${${INTERFACES[$i]}[1]}
	echo "
auto ${INTERFACES[$i]}.$SLICEVLAN
iface ${INTERFACES[$i]}.$SLICEVLAN inet static
address $addr
netmask $netmask">> /etc/network/interfaces
done

echo -e "\n-Setting static routes"
declare -a ENDIPS
for i in ${TAP[@]}; do
	eval ELEMENT=\${${i}[2]}
	if [ $(echo ${ENDIPS[@]} | grep -o $ELEMENT | wc -w) -eq 0 ]
		then
			ENDIPS[${#ENDIPS[@]}]=$ELEMENT
	fi
done
for (( i=0; i<${#ENDIPS[@]}; i++ )); do
	eval remoteaddr=\${${ENDIPS[$i]}[0]}
	eval interface=\${${ENDIPS[$i]}[1]}
	sed -i "/iface $interface.$SLICEVLAN inet static/a\
up route add -host $remoteaddr dev $interface.$SLICEVLAN
" /etc/network/interfaces
done

echo -e "\n-Restarting network services"
/etc/init.d/networking restart 

fi

if [ $(ps aux | grep avahi-daemon | wc -l) -gt 1 ]; then
	/etc/init.d/avahi-daemon stop
fi

echo -e "\n-Setting hostname"
# setting hostname in /etc/hostname
echo "$HOST" > /etc/hostname &&
# setting hostname in /etc/hosts
sed -i '2d' /etc/hosts
sed -i "1a\127.0.0.1\t$HOST" /etc/hosts &&
hostname $HOST &&


if [ "$TYPE_OF_TUNNEL" = "openvpn" ];then

echo -e "\n-Configuring OpenVPN"
# writing *.conf OpenVPN files in /etc/openvpn
for i in ${TAP[@]}; do
	eval localport=\${${i}[0]}
    eval remoteport=\${${i}[1]}
	eval remoteaddr=\${!$i[2]}
	echo "dev ${i}
mode p2p
port $localport
remote $remoteaddr $remoteport
script-security 3 system
up \"bash /etc/openvpn/${i}.sh\"" > /etc/openvpn/$i.conf
done

for i in ${TAP[@]}; do
	echo "#!/bin/bash
ip link set ${i} up" > /etc/openvpn/$i.sh
done

echo -e "\n-Starting OpenVPN service"
/etc/init.d/openvpn start 

fi

echo -e "\n-Configuring Quagga"
# ZEBRA.CONF
echo -e "
! -*- zebra -*-
log file /var/log/quagga/zebra.log\n
hostname $HOST
password ${ROUTERPWD}
enable password ${ROUTERPWD}

interface lo
ip address $LOOPBACK
link-detect" > /etc/quagga/zebra.conf &&

if [ "$TYPE_OF_TUNNEL" = "openvpn" ];then

for i in ${TAP[@]}; do
eval quaggaintaddr=\${${i}[3]}
echo -e "
interface ${i}
ip address $quaggaintaddr
link-detect" >> /etc/quagga/zebra.conf
done

elif [ "$TYPE_OF_TUNNEL" = "vxlan" ];then

for i in ${QUAGGAINT[@]}; do
eval quaggaintaddr=\${${i}[0]}
echo -e "
interface ${i}
ip address $quaggaintaddr
link-detect" >> /etc/quagga/zebra.conf
done

fi
# OSPFD.CONF
echo -e "! -*- ospf -*-
!
hostname $HOST
password $ROUTERPWD
log file /var/log/quagga/ospfd.log\n
interface lo
ospf cost ${LOOPBACK[1]}
ospf hello-interval ${LOOPBACK[2]}\n" > /etc/quagga/ospfd.conf &&

if [ "$TYPE_OF_TUNNEL" = "openvpn" ];then

for i in ${TAP[@]}; do
eval quaggaospfcost=\${${i}[4]}
eval quaggahellointerval=\${${i}[5]}
echo -e "interface $i
ospf cost $quaggaospfcost
ospf hello-interval $quaggahellointerval\n" >> /etc/quagga/ospfd.conf
done

elif [ "$TYPE_OF_TUNNEL" = "vxlan" ];then

for i in ${QUAGGAINT[@]}; do
eval quaggaospfcost=\${${i}[1]}
eval quaggahellointerval=\${${i}[2]}
echo -e "interface $i
ospf cost $quaggaospfcost
ospf hello-interval $quaggahellointerval\n" >> /etc/quagga/ospfd.conf
done

fi

echo -e "router ospf\n" >> /etc/quagga/ospfd.conf
for i in ${OSPFNET[@]}; do
	eval quaggaannouncednet=\${${i}[0]}
	eval quaggarouterarea=\${${i}[1]}
	echo "network $quaggaannouncednet area $quaggarouterarea" >> /etc/quagga/ospfd.conf
done

# QUAGGA DAEMONS
sed -i -e 's/zebra=no/zebra=yes/g' /etc/quagga/daemons &&
sed -i -e 's/ospfd=no/ospfd=yes/g' /etc/quagga/daemons &&
echo "babeld=no" >> /etc/quagga/daemons &&

# QUAGGA DEBIAN.CONF
sed -i -e 's/zebra_options=" --daemon -A 127.0.0.1"/zebra_options=" --daemon"/g' /etc/quagga/debian.conf &&
echo -e "babeld_options=\" --daemon -A 127.0.0.1\"\n
# The list of daemons to watch is automatically generated by the init script.
watchquagga_enable=no
watchquagga_options=\"--daemon\"" >> /etc/quagga/debian.conf &&

# QUAGGA VTYSH.CONF
echo "!
!service integrated-vtysh-config
hostname $HOST
username root $ROUTERPWD
!"> /etc/quagga/vtysh.conf &&

# QUAGGA CONF FILE PERMISSIONS
chown quagga:quaggavty /etc/quagga/*.conf &&
chmod 640 /etc/quagga/*.conf &&

# DO NOT DISPLY END SIGN AFTER EACH QUAGGA COMMAND
VTYSH_PAGER=more > /etc/environment &&

# ENABLE LINUX FORWARDING
echo -e "\n-Enabling Linux forwarding"
echo "1" > /proc/sys/net/ipv4/ip_forward &&
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf &&

echo -e "\n-Starting Quagga daemon"
/etc/init.d/quagga start


if [ "$TYPE_OF_TUNNEL" = "vxlan" ];then
	echo -e "\n-Configuring OpenVSwitch"

	# Appending rules to reconfig OVS port associations when the service start, to the service file /etc/init.d/openvswitchd
	echo -e "\n-Setting up DREAMER auto load into OpenvSwitch"
	sed -i '72a\
	bash /etc/dreamer/reconfig-device.sh' /etc/init.d/openvswitchd

fi

echo -e "\n-Setting in bash.rc default root folder after login to /etc/dreamer"
echo -e "cd /etc/dreamer" >> /root/.bashrc

echo -e "\n\nDREAMER IP/SDN hybrid node configuration ended succesfully. Enjoy!\n"

EXIT_SUCCESS=0
exit $EXIT_SUCCESS