#!/bin/bash

# rsync_a_lot.sh - Batch rsync script
# Usage: ./rsync_a_lot.sh <input_file> [rsync_options]
# 
# Input file format: Each line should contain:
# source_path;target_path
#
# Example input file:
# /home/user/documents;/backup/documents
# /var/www/html;user@server:/backup/www
# /home/user/photos;/mnt/backup/photos

# -------------------------------------------------------------------------------

# Check if input file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_file> [rsync_options]"
	echo ""
    echo "Example: $0 sync_list.txt -axHAWXS --numeric-ids --info=progress2"
	echo "Example: $0 sync_list.txt -av --delete --dry-run"
	echo ""
	echo "Default rsync option is '-av --progress'"
	echo "----------------------------------------"
	echo "Example input file:"
	echo "/home/user/documents;/backup/documents"
	echo "/var/www/html;user@server:/backup/www"
	echo "/home/user/photos;/mnt/backup/photos"
    exit 1
fi

INPUT_FILE="$1"
shift  # Remove first argument, rest are rsync options
RSYNC_OPTIONS="$*"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Default rsync options if none provided
if [ -z "$RSYNC_OPTIONS" ]; then
    RSYNC_OPTIONS="-av --progress"
fi

echo "Starting batch rsync with options: $RSYNC_OPTIONS"
echo "Reading from: $INPUT_FILE"
echo "----------------------------------------"

# Initialize counters
total_lines=0
success_count=0
error_count=0

# Read file line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    total_lines=$((total_lines + 1))
    
    # Split line by semicolon
    IFS=';' read -r source target <<< "$line"
    
    # Trim whitespace
    source=$(echo "$source" | xargs)
    target=$(echo "$target" | xargs)
    
    # Check if both source and target are provided
    if [ -z "$source" ] || [ -z "$target" ]; then
        echo "[$total_lines] ERROR: Invalid line format: $line"
        echo "Expected format: source_path;target_path"
        error_count=$((error_count + 1))
        continue
    fi
    
    # Check if source exists
    if [ ! -e "$source" ]; then
        echo "[$total_lines] ERROR: Source not found: $source"
        error_count=$((error_count + 1))
        continue
    fi
    
    echo "[$total_lines] Syncing: $source -> $target"
    
    # Perform rsync
    if rsync $RSYNC_OPTIONS "$source" "$target"; then
        echo "[$total_lines] SUCCESS: $source -> $target"
        success_count=$((success_count + 1))
    else
        echo "[$total_lines] ERROR: Failed to sync $source -> $target"
        error_count=$((error_count + 1))
    fi
    
    echo "----------------------------------------"
    
done < "$INPUT_FILE"

# Summary
echo ""
echo "----------------------------------------"
echo "Batch rsync completed!"
echo "Total operations: $total_lines"
echo "Successful: $success_count"
echo "Failed: $error_count"
echo "----------------------------------------"

if [ $error_count -gt 0 ]; then
    exit 1
fi