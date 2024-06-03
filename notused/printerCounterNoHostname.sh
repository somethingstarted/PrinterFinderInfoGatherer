#!/bin/bash

timestart=$(date +%s.%N)

# Check if SNMP is installed
echo "Checking if SNMP is installed..."
if ! command -v snmpget &> /dev/null; then
    echo "SNMP is not installed. Please install SNMP or run 'sudo bash computersetup.sh'"
    exit 1
else
    echo "SNMP is installed. continuing..."
fi

# Check if bc is installed
echo "Checking if bc is installed..."
if ! command -v bc &> /dev/null; then
    echo "bc is not installed. Please install bc or run 'sudo bash computersetup.sh'"
    exit 1
else
    echo "bc is installed. continuing..."
fi

# Read max_threads from YAML configuration
config_file="config.yaml" # Update this to the path of your YAML file
if ! command -v yq &> /dev/null; then
    echo "yq is not installed. Please install yq or run 'sudo apt-get install yq'"
    exit 1
fi

max_threads=$(yq e '.max_threads' "$config_file")

if [ -z "$max_threads" ]; then
    echo "max_threads not found in $config_file. Using default value of 1."
    max_threads=1
fi

# Get the most recent CSV file from the foundprinters directory
foundprinters_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/foundprinters"
recent_printers_csv=$(ls -t "$foundprinters_dir"/printers_*.csv 2>/dev/null | head -n 1)

if [ -z "$recent_printers_csv" ]; then
    echo "No printer CSV file found in $foundprinters_dir"
    exit 1
fi

echo "Using printers list from $recent_printers_csv"

# Read the printer IPs from the CSV file (first column, starting from the second row)
mapfile -t printer_ips < <(tail -n +2 "$recent_printers_csv" | cut -d',' -f1)

# SNMP community string
community="public"

# OIDs for total printed pages and serial numbers
oid_pages="1.3.6.1.2.1.43.10.2.1.4.1.1"
oid_serial="1.3.6.1.2.1.43.5.1.1.17.1"

# Function to query SNMP for a printer
query_printer() {
  ip=$1
  serial=$(snmpget -v2c -c $community $ip $oid_serial | awk -F ': ' '{print $2}')
  count=$(snmpget -v2c -c $community $ip $oid_pages | awk '{print $4}')
  echo "$ip,$serial,$count"
}

export -f query_printer
export community oid_pages oid_serial

# Run SNMP queries in parallel
results=$(printf "%s\n" "${printer_ips[@]}" | xargs -P "$max_threads" -I {} bash -c 'query_printer "$@"' _ {})

# Prepare the header for CSV file
header="Date,Time"
serials_row=","
counts_row="$(date +"%Y-%m-%d"),$(date +"%H:%M:%S")"

while IFS=, read -r ip serial count; do
  header="$header,$ip"
  serials_row="$serials_row,$serial"
  counts_row="$counts_row,$count"
done <<< "$results"

# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
output_directory="$script_dir/printerCounterOUTPUT"

# Define the filename with the requested naming scheme
filename="totals_$(date +"%Y_%m").csv"

# Ensure the output directory exists
mkdir -p "$output_directory"

# Find the most recently created CSV file in the output directory
recent_csv=$(ls -t "$output_directory"/*.csv 2>/dev/null | head -n 1)

if [ -n "$recent_csv" ]; then
  # CSV file exists, append today's totals to it
  echo "Appending today's totals to the most recently created CSV file..."
  echo "$counts_row" >> "$recent_csv"
else
  # CSV file doesn't exist, create a new one with the header
  echo "Creating a new CSV file with header..."
  {
    echo "$header"
    echo "$serials_row"
    echo "$counts_row"
  } > "$output_directory/$filename"
fi

echo "Totals appended to or written to $filename"

######################
#        cleanup     #
######################

# Number of most recent files to keep before deleting.
files_to_keep=100

# Delete all but the $files_to_keep most recent CSV files in the directory
total_files=$(ls -t "$output_directory"/*.csv | wc -l)
files_to_remove=$((total_files - files_to_keep))

if [ $files_to_remove -gt 0 ]; then
  ls -t "$output_directory"/*.csv | tail -n +$((files_to_keep + 1)) | xargs rm
  echo "$files_to_remove of the oldest files removed."
else
  echo "No files to remove. ($total_files out of $files_to_keep)"
fi

# Export the variables so they are available to the timecalc script
timeend=$(date +%s.%N) #get now's time
export timestart
export timeend
#source timecalc.sh

echo "all done"
