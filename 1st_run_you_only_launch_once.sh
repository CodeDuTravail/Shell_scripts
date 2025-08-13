#!/bin/bash
#
# /src/yolo.sh
#
# Purpose: First script to run. Accepts command line arguments or prompts for inputs.
#
# Usage: ./yolo.sh run [user@hostname:port] [ip_address/cidr] [-y]
# Example: ./yolo.sh run mercy@myserver:2222 192.168.1.50/24
#
# Arguments (all optional):
#   1. user@hostname:port - Username, hostname and SSH port in format user@hostname:port
#   2. ip_address/cidr    - IP address in CIDR notation (e.g., 192.168.1.50/24)
#
# If no arguments provided, script will prompt for all inputs.
# If partial arguments provided, script will prompt for missing ones.
#
# -------------------------------------------------------------------------------
# Actions:
#
#	- Create a sudoer user 
#	- Packages update & install 
#	- Set hostname, backup /etc/hosts, substitute the old hostname entry with the defined one and rotate the files.
#   - Network configuration : IP address, subnet & gateway
#   - SSH port reconfiguration
#   - Generate MOTD files
#
# -------------------------------------------------------------------------------

ROOT_UID=0
SUCCESS=0
E_USEREXISTS=70
E_NOTROOT=87

# Default values
user_name=""
host_name=""
ssh_port=""
ipv4_address=""
ipv4_gateway="192.168.1.254"
ipv4_dns="192.168.1.3 192.168.1.4 192.168.1.2 192.168.1.254 1.1.1.1"
auto_confirm=false

# Function to display help # -------------------------------------------------------------------------------
show_help() {
    echo
    echo "YOLO - You Only Launch Once - Server Setup Script"
    echo
    echo "Usage: $0 <command> [options] [arguments]"
    echo
    echo "Commands:"
    echo "  run                                     Start interactive mode (prompts for all inputs)"
    echo "  run [user@hostname:port]                Interactive mode with partial arguments"
    echo "  run [user@hostname:port] [ip]           Interactive mode with all arguments (still prompts for confirmation)"
    echo "  run -y [user@hostname:port] [ip]        Auto-confirm mode (no prompts if all arguments provided)"
    echo "  run [user@hostname:port] [ip] -y        Auto-confirm mode (-y can be anywhere in arguments)"
    echo
    echo "Options:"
    echo "  -y                                      Auto-confirm all prompts (only works with complete arguments)"
    echo
    echo "Arguments:"
    echo "  user@hostname:port                      Username, hostname and SSH port (e.g., mercy@myserver:2222)"
    echo "  ip_address/cidr                         IP address in CIDR notation (e.g., 192.168.1.50/24)"
    echo
    echo "Examples:"
    echo "  $0                                                      # Show this help"
    echo "  $0 run                                                  # Interactive mode (prompts for all inputs)"
    echo "  $0 run mercy@server:2222                                # Interactive mode, prompts for IP address only"
    echo "  $0 run mercy@server:2222 192.168.1.50/24               # Interactive mode with all arguments provided"
    echo "  $0 run -y mercy@server.company.com:2222 192.168.1.50/24  # Auto-confirm mode (no prompts)"
    echo "  $0 run mercy@server.company.com:2222 192.168.1.50/24 -y  # Auto-confirm mode (-y at end)"
    echo
    echo "Note: The -y flag only works when all required arguments are provided and hostname is a FQDN."
    echo "      If arguments are missing or hostname needs domain input, script will prompt regardless."
    echo
    echo "Actions performed by this script:"
    echo "  - Create a sudoer user account"
    echo "  - Update and install required packages"
    echo "  - Configure hostname and /etc/hosts"
    echo "  - Configure network settings (IP, gateway, DNS)"
    echo "  - Configure SSH port"
    echo
    echo "Note: This script must be run as root."
    echo
    exit 0
}



# Function to get confirmation or auto-confirm # -------------------------------------------------------------------------------
get_confirmation() {
    local prompt="$1"
    local default_response="${2:-N}"
    
    if [ "$auto_confirm" = true ]; then
        echo "$prompt Y (auto-confirmed)"
        return 0
    else
        read -p "$prompt" hitconfirm
        # Convert to uppercase and check
        hitconfirm=$(echo "$hitconfirm" | tr '[:lower:]' '[:upper:]')
        if [ "$hitconfirm" = "Y" ] || [ "$hitconfirm" = "YES" ]; then
            return 0
        else
            return 1
        fi
    fi
}
parse_user_host_port() {
    local input="$1"
    
    # Check if input contains @ and :
    if [[ "$input" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
        user_name="${BASH_REMATCH[1]}"
        host_name="${BASH_REMATCH[2]}"
        ssh_port="${BASH_REMATCH[3]}"
        return 0
    else
        echo "Error: Invalid format for user@hostname:port. Expected format: user@hostname:port"
        echo "Example: mercy@server:2222"
        return 1
    fi
}

# Check for help request or no arguments # -------------------------------------------------------------------------------
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
fi

# Packages install # -------------------------------------------------------------------------------
echo "          ------------------------------------- "	
echo " ** Packages update and install ** "
echo "          ------------------------------------- "	
echo
echo
apt update -y && apt upgrade -y && apt install -y \
mlocate needrestart whois fail2ban \
ntp sysfsutils rsync wget curl git \
htop iftop iptraf-ng rfkill screenfetch inxi figlet
echo
echo

# Check if first argument is 'run' command # -------------------------------------------------------------------------------
if [[ "$1" != "run" ]]; then
    echo "Error: First argument must be 'run' to execute the script."
    echo "Use '$0' (no arguments) to see help, or '$0 run' to start interactive mode."
    echo
    exit 1
fi

# Shift arguments to remove 'run' command # -------------------------------------------------------------------------------
shift

# Parse all arguments to find -y flag anywhere # -------------------------------------------------------------------------------
args=()
for arg in "$@"; do
    if [[ "$arg" == "-y" ]]; then
        auto_confirm=true
        echo "Auto-confirm mode enabled. Will skip prompts if all arguments are provided."
        echo
    else
        args+=("$arg")
    fi
done

# Reset positional parameters with filtered arguments # -------------------------------------------------------------------------------
set -- "${args[@]}"

# Run as root, of course. # -------------------------------------------------------------------------------
if [ "$UID" -ne "$ROOT_UID" ]; then
    echo "Must be root to run this script."
    exit $E_NOTROOT
fi  

echo "          ------------------------------------- "
echo " ** GET READY FOR LAUNCH CONTROL : a YOLO script You Only Launch Once ! ** "
echo "          ------------------------------------- "
echo
echo

# Parse command line arguments # -------------------------------------------------------------------------------
if [ $# -gt 0 ]; then
    echo "Processing command line arguments..."
    echo
    
    # Parse first argument (user@hostname:port)
    if [ -n "$1" ]; then
        if parse_user_host_port "$1"; then
            echo "Parsed from arguments:"
            echo "  Username: $user_name"
            echo "  Hostname: $host_name"
            echo "  SSH Port: $ssh_port"
            echo
        else
            exit 1
        fi
    fi
    
    # Parse second argument (IP address)
    if [ -n "$2" ]; then
        ipv4_address="$2"
        echo "  IP Address: $ipv4_address"
        echo
    fi
    
    # Check if we can use auto-confirm mode
    if [ "$auto_confirm" = true ]; then
        # Check if all required arguments are provided and hostname is FQDN
        if [ -n "$user_name" ] && [ -n "$host_name" ] && [ -n "$ssh_port" ] && [ -n "$ipv4_address" ] && [[ "$host_name" == *"."* ]]; then
            echo "Auto-confirm mode: All arguments provided and hostname is FQDN."
            echo "Proceeding without prompts..."
            echo
        else
            echo "Auto-confirm mode disabled: Missing arguments or hostname is not FQDN."
            echo "Will prompt for missing information and confirmations."
            auto_confirm=false
            echo
        fi
    fi
fi

# Get missing information interactively # -------------------------------------------------------------------------------

# Get username if not provided
if [ -z "$user_name" ]; then
    echo "          ------------------------------------- "
    read -p " Username for new user (default: mercy): " input_user
    user_name="${input_user:-mercy}"
    echo "          ------------------------------------- "
    echo
fi

# Get hostname if not provided
if [ -z "$host_name" ]; then
    echo "          ------------------------------------- "
    read -p " 1/4 - Define Hostname: " host_name
    echo "          ------------------------------------- "
    if ! get_confirmation " Following Hostname to be set: $host_name - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
else
    echo "          ------------------------------------- "
    if ! get_confirmation " Following Hostname to be set: $host_name - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
fi

# Check if hostname is FQDN and handle domain
fqdn=""
short_hostname=""

if [[ "$host_name" == *"."* ]]; then
    echo "          ------------------------------------- "
    echo " ** Hostname '$host_name' appears to be a FQDN ** "
    fqdn="$host_name"
    # Extract short hostname (everything before first dot)
    short_hostname="${host_name%%.*}"
    echo " ** Short hostname: $short_hostname ** "
    echo " ** FQDN: $fqdn ** "
    echo "          ------------------------------------- "
else
    echo "          ------------------------------------- "
    echo " ** Hostname '$host_name' is not a FQDN ** "
    short_hostname="$host_name"
    
    # Auto-confirm is disabled if hostname is not FQDN (already handled above)
    if get_confirmation " Do you want to specify a domain name - Y/N: "; then
        echo "          ------------------------------------- "
        echo
        read -p " Enter domain name (e.g., example.com): " domain
        if [ -n "$domain" ]; then
            fqdn="$host_name.$domain"
            echo "          ------------------------------------- "
            echo " ** Full FQDN will be: $fqdn ** "
            if ! get_confirmation " Use this FQDN - Y/N: "; then
                echo "          ------------------------------------- "
                echo "Script exit."
                exit
            fi
            echo "          ------------------------------------- "
            echo
        else
            echo "          ------------------------------------- "
            echo " ** No domain provided, using default: $host_name.in.dahouse ** "
            fqdn="$host_name.in.dahouse"
            echo "          ------------------------------------- "
        fi
    else
        echo "          ------------------------------------- "
        echo " ** Using default domain: $host_name.in.dahouse ** "
        fqdn="$host_name.in.dahouse"
        echo "          ------------------------------------- "
    fi
fi

# Get IP address if not provided
if [ -z "$ipv4_address" ]; then
    echo "          ------------------------------------- "
    read -p " 2/4 Define IP Address in CIDR 192.168.1._/24: " ipv4_address
    echo "          ------------------------------------- "
    if ! get_confirmation " Following IP Address to be set: $ipv4_address - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
else
    echo "          ------------------------------------- "
    if ! get_confirmation " Following IP Address to be set: $ipv4_address - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
fi

# Get SSH port if not provided
if [ -z "$ssh_port" ]; then
    echo "          ------------------------------------- "
    read -p " 3/4 Define SSH Port: " ssh_port
    echo "          ------------------------------------- "
    if ! get_confirmation " Following SSH Port to be set: $ssh_port - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
else
    echo "          ------------------------------------- "
    if ! get_confirmation " Following SSH Port to be set: $ssh_port - Y/N: "; then
        echo "          ------------------------------------- "
        echo "Script exit."
        exit
    fi
    echo "          ------------------------------------- "
    echo
fi

# Get password for user creation
echo "          ------------------------------------- "
read -s -p " 4/4 Spell the magic word please, for $user_name: " user_pw
echo
echo "          ------------------------------------- "
echo
echo

# Empty password check
if [ "$user_pw" != "" ]; then
    # Check if user already exists.
    grep -q "$user_name" /etc/passwd
    if [ $? -eq $SUCCESS ]; then
        echo "          ------------------------------------- "	
        echo " ** User $user_name does already exist. ** "
        echo " ** Please chose another username. ** "
        echo "          ------------------------------------- "
        echo
        echo
        exit $E_USEREXISTS
    fi  
    
    # Sudoer user creation # Prerequisite for mkpasswd : whois # -------------------------------------------------------------------------------
    useradd -p `mkpasswd "$user_pw"` -d /home/"$user_name" -m -g sudo -s /bin/bash "$user_name"
    
    # Allow no one else to access the home directory of the user
    chmod 750 /home/"$user_name"
    echo "          ------------------------------------- "	
    echo " ** Account created & /home directory is setup for user: $user_name ** "
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

# Set Hostname # -------------------------------------------------------------------------------
echo "          ------------------------------------- "	
echo " ** Set Hostname $short_hostname ** "
echo "          ------------------------------------- "
echo
echo

hostnamectl set-hostname $short_hostname

cp -p /etc/hosts /etc/hosts.bkp
PIF="127.0.1.1       $short_hostname       $fqdn"
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

# Rotate /etc/hosts files to match new hostname # -------------------------------------------------------------------------------
echo "          ------------------------------------- "
if get_confirmation " Rotate /etc/hosts files - Y/N: "; then
    echo
    echo "          ------------------------------------- "
    echo "          ------------------------------------- "	
    echo " ** Rotating /etc/hosts files. ** "
    echo "          ------------------------------------- "
    echo
    cp -p /etc/hosts.set /etc/hosts && cat /etc/hosts
    echo
    echo
else
    echo "          ------------------------------------- "
    echo "Script exit."
    exit
fi 

# Set IP address # -------------------------------------------------------------------------------
echo "          ------------------------------------- "	
echo " ** Network connection configuration ** "
echo "          ------------------------------------- "	
nmcli connection modify eth0 ipv4.addresses "$ipv4_address" ipv4.gateway "$ipv4_gateway"
nmcli c m eth0 ipv4.dns "$ipv4_dns"
nmcli c s eth0 | grep -e "ipv4.dns:" -e "ipv4.addresses" -e "ipv4.gateway"
echo
echo

# Set SSH Port # -------------------------------------------------------------------------------
echo "          ------------------------------------- "	
echo " ** SSH Port configuration ** "
echo "          ------------------------------------- "	

cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.bkp
PAF="Port $ssh_port"
LN=$(grep -n "#Port 22" /etc/ssh/sshd_config | grep -Eo '^[^:]+')

awk -v "LN=$LN" -v "PAF=$PAF" 'NR==LN {$0=PAF} { print }' /etc/ssh/sshd_config > /etc/ssh/sshd_config.set
echo
echo
echo "          ------------------------------------- "	
echo " ** File /etc/ssh/sshd_config.set is ready ** "
echo "          ------------------------------------- "
echo
diff /etc/ssh/sshd_config /etc/ssh/sshd_config.set

echo
echo

# Rotate /etc/ssh/sshd_config files to match new SSH Port configuration # -------------------------------------------------------------------------------
echo "          ------------------------------------- "
if get_confirmation " Rotate /etc/ssh/sshd_config files - Y/N: "; then
    echo
    echo "          ------------------------------------- "
    echo "          ------------------------------------- "	
    echo " ** Rotating /etc/ssh/sshd_config files. ** "
    echo "          ------------------------------------- "
    echo
    cp -p /etc/ssh/sshd_config.set /etc/ssh/sshd_config && grep -n "Port " /etc/ssh/sshd_config
    echo
    echo
else
    echo "          ------------------------------------- "
    echo "Script exit."
    exit
fi 

# Getting Font file for figlet to create hostname banner # -------------------------------------------------------------------------------
if [ -f "/src/ANSI Shadow.flf" ]; then
	echo
	echo "          ------------------------------------- "	
	echo "ANSI Shadow.flf is available"
	echo "          ------------------------------------- "
	echo
else
	echo
	echo "          ------------------------------------- "	
	echo "Requiring ANSI Shadow.flf, downloading it..."
	echo "          ------------------------------------- "
	echo
	cd /src && wget https://raw.githubusercontent.com/xero/figlet-fonts/refs/heads/master/ANSI%20Shadow.flf
	echo
fi

# Generate MOTD file # -------------------------------------------------------------------------------
echo "          ------------------------------------- "
echo " ** Generating MOTD ** "
echo "          ------------------------------------- "
echo "" > /etc/motd
cat >> /etc/motd << EOF
####################################################################################################################


EOF

figlet -f "ANSI Shadow.flf" PITAYA >> /etc/motd

cat >> /etc/motd << EOF

####################################################################################################################

# apt list --upgradable  #------------------------# Check upgradable packages
# apt update -y && apt upgrade -y #---------------# Update & upgrade packages

# screenfetch | htop | iftop | iptraf-ng

# nmcli connection modify eth0 ipv4.addresses "$ipv4_address" ipv4.gateway "$ipv4_gateway"
# nmcli c m eth0 ipv4.dns "$ipv4_dns"
# nmcli c s eth0 | grep -e "ipv4.addresses" -e "ipv4.gateway" -e "ipv4.dns:"

# systemctl restart NetworkManager

# fail2ban-client status JAIL_NAME #---------------------------# Check fail2ban jail status
# fail2ban-client set JAIL_NAME banip $IP #----------------# Ban IP

####################################################################################################################
EOF
echo
echo
#cat /etc/motd
echo
echo
echo

# Generate CUSTOM UPDATE MOTD file # -------------------------------------------------------------------------------
cat >> /etc/update-motd.d/01-custom << EOF
#!/bin/sh
echo "GENERAL SYSTEM INFORMATION"
/usr/bin/screenfetch
echo "RPI SYSTEM USAGE"
export TERM=xterm; inxi -Dsm
echo
echo "# APT LIST UPGRADABLE ###########################################"
echo
sudo apt list --upgradable
echo
echo "# REBOOT REQUIRED CHECK ###########################################"
echo
if [ -f /var/run/reboot-required ]
then
    echo "[*** Hello $USER, you must reboot your machine ***]"
fi
echo
echo "# DMESG ERRORS ###########################################"
echo
dmesg -T | grep -i -e "error" -e "fail" -e "warn"
echo
echo "############################################"
EOF

chmod a+x /etc/update-motd.d/*
echo
echo
echo
#cat /etc/update-motd.d/01-custom

echo
echo
echo "          ------------------------------------- "	
echo " ** Reboot Now or Run this CLI to apply connection configuration changes: systemctl restart NetworkManager"
echo "          ------------------------------------- "
echo
echo
exit 0