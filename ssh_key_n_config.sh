#!/bin/bash

# Script: ssh_key_n_config.sh
# Usage: ./ssh_key_n_config.sh user@server:port
# Description: Generates an ed25519 SSH key and creates SSH config entry

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 user@server:port"
    echo "Example: $0 john@example.com:2222"
    exit 1
fi

# Parse the input argument
input="$1"

# Extract username (everything before @)
if [[ "$input" =~ ^([^@]+)@(.+)$ ]]; then
    user_name="${BASH_REMATCH[1]}"
    server_and_port="${BASH_REMATCH[2]}"
else
    echo "Error: Invalid format. Expected format: user@server:port"
    exit 1
fi

# Extract server and port (split by :)
if [[ "$server_and_port" =~ ^([^:]+):([0-9]+)$ ]]; then
    target_server="${BASH_REMATCH[1]}"
    ssh_port="${BASH_REMATCH[2]}"
else
    echo "Error: Invalid format. Expected format: user@server:port"
    exit 1
fi

# Display parsed values
echo "Parsed values:"
echo "  Username: $user_name"
echo "  Server: $target_server"
echo "  Port: $ssh_port"
echo

# Define key file path
key_file="$HOME/.ssh/id_ed25519_$user_name-$target_server"

# Check if key already exists
if [ -f "$key_file" ]; then
    echo "Warning: SSH key $key_file already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        exit 1
    fi
fi

# Create .ssh directory if it doesn't exist
mkdir -p "$HOME/.ssh"

# Generate SSH key
echo "Generating ed25519 SSH key..."
ssh-keygen -t ed25519 -f "$key_file" -C "$user_name@$target_server" -N ""

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate SSH key"
    exit 1
fi

# Set proper permissions
chmod 600 "$key_file"
chmod 644 "${key_file}.pub"

echo "SSH key generated successfully!"
echo "  Private key: $key_file"
echo "  Public key: ${key_file}.pub"
echo

# Create SSH config entry
config_file="$HOME/.ssh/config"
host_entry="$user_name.$target_server"

# Check if host entry already exists in config
if [ -f "$config_file" ] && grep -q "^Host $host_entry$" "$config_file"; then
    echo "Warning: Host entry '$host_entry' already exists in SSH config!"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove existing entry (from Host line to next Host line or end of file)
        sed -i "/^Host $host_entry$/,/^Host /{ /^Host $host_entry$/d; /^Host /!d; }" "$config_file"
        # Remove the last Host line that was kept
        sed -i "/^Host $host_entry$/,\${ /^Host $host_entry$/d; /^$/d; }" "$config_file"
    else
        echo "Keeping existing SSH config entry."
        exit 0
    fi
fi

# Add new SSH config entry
echo "Adding entry to SSH config..."
cat >> "$config_file" << EOF

Host $host_entry
    HostName $target_server
    Port $ssh_port
    User $user_name
    IdentityFile $key_file
    IdentitiesOnly yes
EOF

# Set proper permissions for config file
chmod 600 "$config_file"

echo "SSH config entry added successfully!"
echo

# Ask user if they want to copy the public key to the server
read -p "Do you want to copy the public key to the server now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Copying public key to server..."
    echo "You may be prompted for your password on the remote server."
    
    ssh-copy-id -p $ssh_port -i "${key_file}.pub" "$user_name@$target_server"
    
    if [ $? -eq 0 ]; then
        echo
        echo "Public key copied successfully!"
        echo "You can now connect using:"
        echo "  ssh $host_entry"
    else
        echo
        echo "Failed to copy public key. You can try manually:"
        echo "  sudo ssh-copy-id -p $ssh_port -i ${key_file}.pub $user_name@$target_server"
        echo "  or manually add the contents of ${key_file}.pub to ~/.ssh/authorized_keys on the server"
    fi
else
    echo "Skipping public key copy."
    echo "You can copy it later using:"
    echo "  sudo ssh-copy-id -p $ssh_port -i ${key_file}.pub $user_name@$target_server"
    echo "  or manually add the contents of ${key_file}.pub to ~/.ssh/authorized_keys on the server"
    echo
    echo "After copying the key, you can connect using:"
    echo "  ssh $host_entry"
fi
