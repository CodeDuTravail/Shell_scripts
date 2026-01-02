#!/bin/bash

################################################################################################################

# Input file hosts_checklist.txt only needs hostnames in it, nslookup task is done to retrieve IP.
# Only if host reacts to ping, it's added to ansible inventory

# /!\ SSH Arg StrictHostKeyChecking=no Set for cases of cloned templates by laziest admins.

################################################################################################################

# Configuration variables
INPUT_FILE="hosts_checklist.txt"
LOG_FILE="hosts_checked.txt"
ANSIBLE_INVENTORY="inv_checked.yml"
ADM_ACCOUNT="YOUR_ANSIBLE_USER"


# Check if ansible inventory file already exists and determine filename
if [ -f "inv_checked.yml" ]; then
    DATE_SUFFIX=$(date +%Y_%m_%d)
    ANSIBLE_INVENTORY="inv_checked_${DATE_SUFFIX}.yml"
    
    # If date-based file also exists, add timestamp
    if [ -f "$ANSIBLE_INVENTORY" ]; then
        TIMESTAMP=$(date +%Y_%m_%d_%H%M%S)
        ANSIBLE_INVENTORY="inv_checked_${TIMESTAMP}.yml"
        echo "Warning: inv_checked.yml and date-based file already exist. Using timestamp: $ANSIBLE_INVENTORY"
    else
        echo "Warning: inv_checked.yml already exists. Using date-based filename: $ANSIBLE_INVENTORY"
    fi
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found!"
    exit 1
fi

# Clear or create the log file
> "$LOG_FILE"

# Initialize Ansible inventory file
> "$ANSIBLE_INVENTORY"

# Arrays to store hosts by environment
declare -A prod_hosts
declare -A dev_hosts
declare -A rec_hosts
declare -A test_hosts

# Read each line from host_check.txt
while IFS= read -r hostname || [ -n "$hostname" ]; do
    # Skip empty lines
    [ -z "$hostname" ] && continue
    
    # Trim whitespace
    hostname=$(echo "$hostname" | xargs)
    
    echo "Processing: $hostname"
    
    # Perform nslookup to get IP address
    ip=$(nslookup "$hostname" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -n 1)
    
    # Check if DNS lookup was successful
    if [ -z "$ip" ]; then
        echo "  DNS lookup failed for $hostname"
        echo "$hostname,no_record,dns_failed" >> "$LOG_FILE"
        continue
    fi
    
    echo "  IP found: $ip"
    
    # Ping the IP address (2 tries, 1 second timeout each)
    if ping -c 2 -W 1 "$ip" > /dev/null 2>&1; then
        echo "  Ping successful"
        echo "$hostname,$ip,up" >> "$LOG_FILE"
        
        # Convert hostname to lowercase for case-insensitive matching
        hostname_lower=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')
        
        # Determine environment based on hostname and add to inventory
        if [[ "$hostname_lower" == *"prod"* ]]; then
            prod_hosts["$hostname"]="$ip"
        elif [[ "$hostname_lower" == *"dev"* ]]; then
            dev_hosts["$hostname"]="$ip"
        elif [[ "$hostname_lower" == *"rec"* ]]; then
            rec_hosts["$hostname"]="$ip"
        elif [[ "$hostname_lower" == *"test"* ]]; then
            test_hosts["$hostname"]="$ip"
        fi
    else
        echo "  Ping failed"
        echo "$hostname,$ip,down" >> "$LOG_FILE"
    fi
    
done < "$INPUT_FILE"

# Generate Ansible inventory file
echo "---" > "$ANSIBLE_INVENTORY"
echo "all:" >> "$ANSIBLE_INVENTORY"
echo "  children:" >> "$ANSIBLE_INVENTORY"

# Add prod hosts
echo "    prod:" >> "$ANSIBLE_INVENTORY"
echo "      hosts:" >> "$ANSIBLE_INVENTORY"
if [ ${#prod_hosts[@]} -eq 0 ]; then
    echo "        # No prod hosts found" >> "$ANSIBLE_INVENTORY"
else
    for hostname in "${!prod_hosts[@]}"; do
        ip="${prod_hosts[$hostname]}"
        hostname_lower=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')
        echo "        $hostname_lower:" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_host: $ip" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_connection: ssh" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_user: $ADM_ACCOUNT" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_port: 22" >> "$ANSIBLE_INVENTORY"
    done
fi

# Add dev hosts
echo "    dev:" >> "$ANSIBLE_INVENTORY"
echo "      hosts:" >> "$ANSIBLE_INVENTORY"
if [ ${#dev_hosts[@]} -eq 0 ]; then
    echo "        # No dev hosts found" >> "$ANSIBLE_INVENTORY"
else
    for hostname in "${!dev_hosts[@]}"; do
        ip="${dev_hosts[$hostname]}"
        hostname_lower=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')
        echo "        $hostname_lower:" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_host: $ip" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_connection: ssh" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_user: $ADM_ACCOUNT" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_port: 22" >> "$ANSIBLE_INVENTORY"
    done
fi

# Add rec hosts
echo "    rec:" >> "$ANSIBLE_INVENTORY"
echo "      hosts:" >> "$ANSIBLE_INVENTORY"
if [ ${#rec_hosts[@]} -eq 0 ]; then
    echo "        # No rec hosts found" >> "$ANSIBLE_INVENTORY"
else
    for hostname in "${!rec_hosts[@]}"; do
        ip="${rec_hosts[$hostname]}"
        hostname_lower=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')
        echo "        $hostname_lower:" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_host: $ip" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_connection: ssh" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_user: $ADM_ACCOUNT" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_port: 22" >> "$ANSIBLE_INVENTORY"
    done
fi

# Add test hosts
echo "    test:" >> "$ANSIBLE_INVENTORY"
echo "      hosts:" >> "$ANSIBLE_INVENTORY"
if [ ${#test_hosts[@]} -eq 0 ]; then
    echo "        # No test hosts found" >> "$ANSIBLE_INVENTORY"
else
    for hostname in "${!test_hosts[@]}"; do
        ip="${test_hosts[$hostname]}"
        hostname_lower=$(echo "$hostname" | tr '[:upper:]' '[:lower:]')
        echo "        $hostname_lower:" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_host: $ip" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_connection: ssh" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_user: $ADM_ACCOUNT" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'" >> "$ANSIBLE_INVENTORY"
        echo "          ansible_port: 22" >> "$ANSIBLE_INVENTORY"
    done
fi

echo ""
echo "Check complete. Results written to $LOG_FILE"
echo "Ansible inventory written to $ANSIBLE_INVENTORY"
