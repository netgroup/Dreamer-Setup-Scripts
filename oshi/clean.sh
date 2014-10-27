#!/bin/bash
# The resets to the default state a DREAMER IP/SDN Hybrid node

echo -e "\n"
echo "#############################################################"
echo "##  DREAMER IP/SDN Hyibrid node configuration cleaning     ##"
echo "##                                                         ##"
echo "## The cleaning process can last many minutes. Please,     ##"
echo "## do not interrupt the process.                           ##"
echo "#############################################################"

# Reset of OpenVSwitch
for i in $(ovs-vsctl list-br); do
	ovs-vsctl del-br $i
done

ovs-dpctl del-dp ovs-system

# OpenVPN
if [ $(ip link show | grep tap | wc -l) -gt 0 ]; then
	echo -e "\n-Turning off tap interfaces"
	declare -a tap
	counter=1
	endofcounter=$(($(ip link show | grep tap | wc -l) + 1))
	while [ $counter -lt $endofcounter ]; do
			arraycounter=$(($counter-1))
			tap[$arraycounter]=$(ip link show | grep tap | sed -n "$counter p" | awk '{split($0,a," "); print a[2]}' | awk '{split($0,a,":"); print a[1]}')
			let counter=counter+1
	done
	for (( i=0; i<${#tap[@]}; i++ )); do
		ip link set ${tap[$i]} down
	done
fi
if [ $(ps aux | grep openvpn | wc -l) -gt 1 ]; then
	echo -e "\n-Turning off OpenVPN service"
	/etc/init.d/openvpn stop
fi
echo -e "\n-Removing configuration files"
rm /etc/openvpn/*.conf 2> /dev/null
rm /etc/openvpn/*.sh 2> /dev/null

# Reset of Quagga
if [ $(ps aux | grep quagga | wc -l) -gt 1 ]
  then
	echo -e "\n-Turning off Quagga service"
	/etc/init.d/quagga stop
fi
echo -e "\n-Reset of zebra.conf file"
cp /usr/share/doc/quagga/examples/zebra.conf.sample /etc/quagga/zebra.conf
echo -e "\n-Reset of ospfd.conf file"
cp /usr/share/doc/quagga/examples/ospfd.conf.sample /etc/quagga/ospfd.conf
echo -e "\n-Reset of quagga daemons file"
sed -i -e 's/zebra=yes/zebra=no/g' /etc/quagga/daemons &&
sed -i -e 's/ospfd=yes/ospfd=no/g' /etc/quagga/daemons &&
sed -i '/babeld=no/d' /etc/quagga/daemons &&
echo -e "\n-Reset of debian.conf file"
sed -i -e 's/zebra_options=" --daemon"/zebra_options=" --daemon -A 127.0.0.1"/g' /etc/quagga/debian.conf &&
sed -i -e 's/babeld_options=" --daemon -A 127.0.0.1"//g' /etc/quagga/debian.conf &&
sed -i -e 's/# The list of daemons to watch is automatically generated by the init script.//g' /etc/quagga/debian.conf &&
sed -i -e 's/watchquagga_enable=no//g' /etc/quagga/debian.conf &&
sed -i -e 's/watchquagga_options="--daemon"//g' /etc/quagga/debian.conf &&
sed -i -e '/^$/d' /etc/quagga/debian.conf &&
if [ -f /etc/quagga/vtysh.conf ]; then
    rm /etc/quagga/vtysh.conf
fi
echo -e "\n-Disabling Linux forwarding"
echo "0" > /proc/sys/net/ipv4/ip_forward &&
sed -i -e 's/net.ipv4.ip_forward = 1//g' /etc/sysctl.conf &&
sed -i -e '/^$/d' /etc/sysctl.conf &&

# ENABLE LINUX RPF
echo -e "\n-Enabling Linux RPF"
sysctl -w "net.ipv4.conf.all.rp_filter=1" &&

# Reset static routes
declare -a remoteaddr
declare -a interfaces
counter=1
endofcounter=$(($(route -n | grep UH | wc -l) + 1))
while [ $counter -lt $endofcounter ]; do
        arraycounter=$(($counter-1))
        interfaces[$arraycounter]=$(route -n | grep UH | sed -n "$counter p" | awk '{split($0,a," "); print a[8]}')
        remoteaddr[$arraycounter]=$(route -n | grep UH | sed -n "$counter p" | awk '{split($0,a," "); print a[1]}')
		let counter=counter+1
done

echo -e "\n-Removing static routes"
for (( i=0; i<${#interfaces[@]}; i++ )); do
	route del -host ${remoteaddr[$i]} dev ${interfaces[$i]}
done
unset interfaces

# Reset VLAN interfaces
declare -a vlan
declare -a interfaces
counter=1
endofcounter=$(($(ip link show | grep -e "eth[0-9]\." | wc -l) + 1))
while [ $counter -lt $endofcounter ]; do
        arraycounter=$(($counter-1))
        interfaces[$arraycounter]=$(ip link show | grep -e "eth[0-9]\." | sed -n "$counter p" | awk '{split($0,a,":"); print a[2]}' | awk '{split($0,a,"@"); print a[1]}' |  awk '{split($0,a,"."); print a[1]}')
        vlan[$arraycounter]=$(ip link show | grep -e "eth[0-9]\." | sed -n "$counter p" | awk '{split($0,a,":"); print a[2]}' | awk '{split($0,a,"@"); print a[1]}' |  awk '{split($0,a,"."); print a[2]}')
        let counter=counter+1
done

echo -e "\n-Turning off VLAN interfaces"
for (( i=0; i<${#interfaces[@]}; i++ )); do
        ip link set $(echo "${interfaces[$i]}.${vlan[$i]}") down
done

echo -e "\n-Removing VLAN settings on all interfaces"
for (( i=0; i<${#interfaces[@]}; i++ )); do
	vconfig rem ${interfaces[$i]}.${vlan[$i]}
done


# Reset Hostname to default (oshi)
echo -e "\n-Setting hostname"
# setting hostname in /etc/hostname
echo "node" > /etc/hostname &&
# removing second line from /etc/hosts
sed -i '2d' /etc/hosts
# adding new line to /etc/hosts with 127.0.0.1 oshi
sed -i "1a\127.0.0.1\tnode" /etc/hosts &&
# setting up hostname
hostname node &&

# Deactivating unuseful interfaces (except management interface eth0) with ip link set ethX down
unset interfaces
declare -a interfaces
counter=1
endofcounter=$(($(ip link show | grep -e "eth[^0e]" | wc -l) + 1))
while [ $counter -lt $endofcounter ]; do
        arraycounter=$(($counter-1))
        interfaces[$arraycounter]=$(ip link show | grep -e "eth[^0e]" | sed -n "$counter p" | awk '{split($0,a," "); print a[2]}' | awk '{split($0,a,":"); print a[1]}')
        let counter=counter+1
done
echo -e "\n-Deactivating physical interfaces"
for (( i=0; i<${#interfaces[@]}; i++ )); do
	ip link set ${interfaces[$i]} down
done

echo -e "\n-Removing loopback address"
ip addr del $(ip a | grep "scope global lo" | awk '{split($0,a," "); print a[2]}') dev lo &&


echo -e "\n-Restarting network services"
/etc/init.d/networking restart &&

echo -e "\n-Removing VSF/VS deployed"
python vs/clean.py

echo -e "\n\nDREAMER configuration cleaning ended succesfully. Enjoy!\n"

EXIT_SUCCESS=0
exit $EXIT_SUCCESS
