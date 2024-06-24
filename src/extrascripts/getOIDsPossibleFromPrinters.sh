#!/bin/bash

# Define the folder for the output
# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OUTPUT_DIR="$script_dir/allprinters"
mkdir -p "$OUTPUT_DIR"

# Prompt for the IP address of the printer
read -p "Enter the IP address of the printer: " printer_ip

# Function to perform SNMP request and write to file
process_printer() {
    local ip=$1
    local filepath="$OUTPUT_DIR/${ip//./_}.txt"

    # Check if the file for this IP already exists
    if [[ -f "$filepath" ]]; then
        echo "Printer at IP $ip already processed. Skipping..."
        return
    fi

    # Perform the SNMP walk and TEE the console output to the file
    snmpwalk -v 2c -c public "$ip" .1 | tee "$filepath"
}

# Process the printer
process_printer "$printer_ip"
