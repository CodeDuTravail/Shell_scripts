#!/bin/bash
#
# /src/yolo.sh
#
# Purpose: First script to run. 4 inputs required.
#
#	- HOSTNAME
#	- IP ADDRESS
#	- SSH PORT
#	- USER PASSWORD
#
# -------------------------------------------------------------------------------
# Actions:
#
#	- Create a sudoer user 
#	- Packages update & install 
#	- Set hostname, backup /etc/hosts, substitute the old hostname entry with the defined one and rotate the files.
#
# -------------------------------------------------------------------------------
#
# Variables setup

ROOT_UID=0
SUCCESS=0
E_USEREXISTS=70

# Set your ansible user
user_name=ANSIBLE_USER

# Set your gateway and DNS servers
ipv4_gateway="X.X.X.X"
ipv4_dns="8.8.8.8 1.1.1.1 9.9.9.9"

# Run as root, of course. (this might not be necessary, because we have to run the script somehow with root anyway)
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script."
    exit $E_NOTROOT
fi  

echo "          ------------------------------------- "
echo " ** GET READY FOR LAUNCH CONTROL : a YOLO script You Only Launch Once ! ** "
echo "          ------------------------------------- "
echo
echo


# Define Hostname
echo "          ------------------------------------- "
read -p " 1/4 - Define Hostname : " host_name; echo "          ------------------------------------- "
read -p " Following Hostname to be set : $host_name - Y/N : " hitconfirm; echo "          ------------------------------------- "
echo
echo
if [ "$hitconfirm" = "N" ]
then
    echo "Script exit."
	exit
fi


# Define IP Address
echo "          ------------------------------------- "
read -p " 2/4 Define IP Address in CIDR 192.168.1._/24 : " ipv4_address; echo
echo "          ------------------------------------- "
read -p " Following IP Address to be set : $ipv4_address - Y/N : " hitconfirm; echo
echo "          ------------------------------------- "
echo
if [ "$hitconfirm" = "N" ]
then
    echo "Script exit."
	exit
fi  

# Define SSH Port
echo "          ------------------------------------- "
read -p " 3/4 Define SSH Port : " ssh_port; echo
echo "          ------------------------------------- "
read -p " Following SSH Port to be set : $ssh_port - Y/N : " hitconfirm; echo
echo "          ------------------------------------- "
echo
if [ "$hitconfirm" = "N" ]
then
    echo "Script exit."
	exit
fi  

# Get password for user creation
echo "          ------------------------------------- "
read -s -p " 4/4 Spell the magic word please, for $user_name : " user_pw; echo
echo "          ------------------------------------- "
echo
echo


# Empty password check
if [ "$user_pw" != "" ]
then

	# Check if user already exists.
	grep -q "$user_name" /etc/passwd
	if [ $? -eq $SUCCESS ] 
	then
		echo "          ------------------------------------- "	
		echo " ** User $username does already exist. ** "
		echo " ** Please chose another username. ** "
		echo "          ------------------------------------- "
		echo
		echo
		exit $E_USEREXISTS
	fi  
	
	# Prerequisite for mkpasswd : whois
	apt update -y && apt upgrade -y && apt install whois -y

	useradd -p `mkpasswd "$user_pw"` -d /home/"$user_name" -m -g users -s /bin/bash "$user_name"
	
	# Allow no one else to access the home directory of the user
	chmod 750 /home/"$user_name"
    echo "          ------------------------------------- "	
	echo " ** Account created & /home directory is setup for user : $user_name ** "
    echo "          ------------------------------------- "	
	echo
	echo
	ls -ltrah /home | grep $user_name
	echo
    cat /etc/passwd | grep $user_name
	echo
	echo
else
    echo "          ------------------------------------- "	
    echo " ** Password can't be blank. Creation aborted. ** "
    echo "          ------------------------------------- "	
	echo
	echo
fi


# Packages install
echo "          ------------------------------------- "	
echo " ** Packages update and install ** "
echo "          ------------------------------------- "	
echo
echo
apt update -y && apt upgrade -y && apt install -y \
mlocate needrestart \
ntp sysfsutils rsync wget curl \
htop iftop iptraf-ng rfkill screenfetch fail2ban duf
echo
echo


# Set Hostname
echo "          ------------------------------------- "	
echo " ** Set Hostname $host_name ** "
echo "          ------------------------------------- "
echo
echo
hostnamectl set-hostname $host_name

cp -p /etc/hosts /etc/hosts.bkp
PIF="127.0.1.1       $host_name       $host_name.in.dahouse"
LN=$(grep -n "127.0.1.1" /etc/hosts | grep -Eo '^[^:]+')

awk -v "LN=$LN" -v "PIF=$PIF" 'NR==LN {$0=PIF} { print }' /etc/hosts | tee /etc/hosts.set
echo
echo
echo "          ------------------------------------- "	
echo " ** File /etc/hosts.set is ready ** "
echo "          ------------------------------------- "
echo
diff /etc/hosts /etc/hosts.set

echo
echo

# Rotate /etc/hosts files to match new hostname
echo "          ------------------------------------- "
read -p " Rotate /etc/hosts files - Y/N : " hitconfirm; echo
echo "          ------------------------------------- "
echo
if [ "$hitconfirm" = "N" ]
then
    echo "Script exit."
else
    echo "          ------------------------------------- "	
    echo " ** Rotating /etc/hosts files. ** "
    echo "          ------------------------------------- "
	echo
	cp -p /etc/hosts.set /etc/hosts && cat /etc/hosts
	echo
	echo
fi 

# Set IP address
echo "          ------------------------------------- "	
echo " ** Network connection configuration ** "
echo "          ------------------------------------- "	
nmcli connection modify eth0 ipv4.addresses "$ipv4_address" ipv4.gateway "$ipv4_gateway"
nmcli c m eth0 ipv4.dns "$ipv4_dns"
nmcli c s eth0 | grep -e "ipv4.dns:" -e "ipv4.addresses" -e "ipv4.gateway"
echo
echo

# Set SSH Port
echo "          ------------------------------------- "	
echo " ** SSH Port configuration ** "
echo "          ------------------------------------- "	

cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.bkp
PAF="Port $ssh_port"
LN=$(grep -n "#Port 22" /etc/ssh/sshd_config | grep -Eo '^[^:]+')

awk -v "LN=$LN" -v "PAF=$PAF" 'NR==LN {$0=PAF} { print }' /etc/ssh/sshd_config | tee /etc/ssh/sshd_config.set
echo
echo
echo "          ------------------------------------- "	
echo " ** File /etc/hosts.set is ready ** "
echo "          ------------------------------------- "
echo
diff /etc/ssh/sshd_config /etc/ssh/sshd_config.set

echo
echo

echo "          ------------------------------------- "
read -p " Rotate /etc/ssh/sshd_config files - Y/N : " hitconfirm; echo
echo "          ------------------------------------- "
echo
if [ "$hitconfirm" = "N" ]
then
    echo "Script exit."
else
    echo "          ------------------------------------- "	
    echo " ** Rotating /etc/ssh/sshd_config files. ** "
    echo "          ------------------------------------- "
	echo
	cp -p /etc/ssh/sshd_config.set /etc/ssh/sshd_config && grep -n "Port " /etc/ssh/sshd_config
	echo
	echo
fi 


echo "          ------------------------------------- "	
echo " ** Reboot Now or Run this CLI to apply connection configuration changes : systemctl restart NetworkManager"
echo "          ------------------------------------- "
echo
echo
exit 0