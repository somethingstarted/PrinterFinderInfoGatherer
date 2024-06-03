#!/bin/bash

# Define the folder for the output
# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
OUTPUT_DIR="$script_dir/allprinters"
mkdir -p "$OUTPUT_DIR"

# Find the latest CSV file in ./foundprinters
CSV_FILE=$(ls ./foundprinters/printers_*.csv | sort | tail -n 1)

# Check if a CSV file was found
if [[ ! -f "$CSV_FILE" ]]; then
    echo "No CSV file found in ./foundprinters."
    exit 1
fi

# Function to get the model name of the printer
get_printer_model() {
    local ip="$1"
    local model_oid="1.3.6.1.2.1.25.3.2.1.3" # Example OID for printer model; update this to the correct OID
    snmpget -v 2c -c public "$ip" "$model_oid" | grep -oP '(?<=STRING: ).*'
}

# Function to perform SNMP request and write to file
process_printer() {
    local ip=$1
    local model=$2

    # Replace spaces and other non-alphanumeric characters with underscores
    local filename=$(echo "$model" | tr ' ' '_')
    local filepath="$OUTPUT_DIR/$filename.txt"

    # Check if the file for this model already exists
    if [[ -f "$filepath" ]]; then
        echo "Model $model already processed. Skipping..."
        return
    fi

    # Perform the SNMP walk and TEE the console output to the file
    snmpwalk -v 2c -c public "$ip" .1 | tee "$filepath"
}

# Read the CSV file and process each line
while IFS=, read -r ip model serial hostname; do
    # Skip the header line
    if [[ "$ip" == "ip" ]]; then
        continue
    fi

    # Get the model name from SNMP if not provided in the CSV
    if [[ -z "$model" ]]; then
        model=$(get_printer_model "$ip")
    fi

    # Process each printer
    process_printer "$ip" "$model"
done < "$CSV_FILE"
