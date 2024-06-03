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

# Get the most recent CSV file from the foundprinters directory
foundprinters_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/foundprinters"
recent_printers_csv=$(ls -t "$foundprinters_dir"/printers_*.csv 2>/dev/null | head -n 1)

if [ -z "$recent_printers_csv" ]; then
    echo "No printer CSV file found in $foundprinters_dir"
    exit 1
fi

echo "Using printers list from $recent_printers_csv"

# Read the printer IPs and other details from the CSV file
printer_ips=()
printer_hostnames_csv=()
printer_serials_csv=()
while IFS=, read -r ip hostname serial; do
  printer_ips+=("$ip")
  printer_hostnames_csv+=("$hostname")
  printer_serials_csv+=("$serial")
done < <(tail -n +2 "$recent_printers_csv")

# SNMP community string
community="public"

# OIDs for total printed pages, serial numbers, and hostnames
oid_pages="1.3.6.1.2.1.43.10.2.1.4.1.1"
oid_serial="1.3.6.1.2.1.43.5.1.1.17.1"
oid_hostname="1.3.6.1.2.1.1.5.0"

# Initialize associative arrays for printers
declare -A printer_counts

# Query each printer for hostname, serial number, and page count
for ip in "${printer_ips[@]}"; do
  echo "Querying printer: $ip"
  hostname=$(snmpget -v2c -c $community $ip $oid_hostname | awk -F ': ' '{print $2}')
  serial=$(snmpget -v2c -c $community $ip $oid_serial | awk -F ': ' '{print $2}')
  count=$(snmpget -v2c -c $community $ip $oid_pages | awk '{print $4}')
  
  echo "IP: $ip, Hostname: $hostname, Serial: $serial, Page Count: $count"
  
  if [ -z "$serial" ]; then
    serial="unknown-$ip"
  fi

  printer_counts["$serial"]="$count"
done

# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
output_directory="$script_dir/printerCounterOUTPUT"

# Define the filename with the requested naming scheme
filename="totals_$(date +"%Y_%m").csv"

# Ensure the output directory exists
mkdir -p "$output_directory"

# Function to append empty fields to match columns
function append_empty_fields {
  local target_length=$1
  local current_length=$2
  local result=""

  for ((i=current_length; i<target_length; i++)); do
    result="$result,"
  done

  echo "$result"
}

# Find the most recently created CSV file in the output directory
recent_csv=$(ls -t "$output_directory"/*.csv 2>/dev/null | head -n 1)

# Prepare new headers and rows
new_header=",printer IP:"
new_hostnames=",Hostnames:"
new_serials=",Serial"
new_counts_row="$(date +"%Y-%m-%d"),$(date +"%H:%M:%S")"

# Ensure all rows have the same length
row_length=${#printer_ips[@]}
for ((i=0; i<row_length; i++)); do
  ip="${printer_ips[$i]}"
  hostname="${printer_hostnames_csv[$i]}"
  serial="${printer_serials_csv[$i]}"
  count="${printer_counts[$serial]}"

  new_header="$new_header,$ip"
  new_hostnames="$new_hostnames,$hostname"
  new_serials="$new_serials,$serial"
  
  if [ -n "$count" ]; then
    new_counts_row="$new_counts_row,$count"
  else
    new_counts_row="$new_counts_row,"
  fi
done

if [ -n "$recent_csv" ]; then
  # CSV file exists, append today's totals to it
  echo "Appending today's totals to the most recently created CSV file..."
  {
    echo "$new_header"
    echo "$new_hostnames"
    echo "$new_serials"
    tail -n +4 "$recent_csv"
    echo "$new_counts_row"
  } > temp.csv
  mv temp.csv "$recent_csv"
else
  # CSV file doesn't exist, create a new one with the header
  echo "Creating a new CSV file with header..."
  {
    echo "$new_header"
    echo "$new_hostnames"
    echo "$new_serials"
    echo "Date,Time,page counts >>>"
    echo "$new_counts_row"
  } > "$output_directory/$filename"
fi

echo "Totals appended to or written to $filename"

# Export the variables so they are available to the timecalc script
timeend=$(date +%s.%N) #get now's time
export timestart
export timeend

echo "all done"
