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

# Read the printer IPs from the CSV file (first column, starting from the second row)
mapfile -t printer_ips < <(tail -n +2 "$recent_printers_csv" | cut -d',' -f1)

# SNMP community string
community="public"

# OIDs for total printed pages and serial numbers
oid_pages="1.3.6.1.2.1.43.10.2.1.4.1.1"
oid_serial="1.3.6.1.2.1.43.5.1.1.17.1"

# Prepare the header for CSV file
header=",printer IP:"
for ip in "${printer_ips[@]}"; do
  header="$header,$ip"
done

# Prepare the row for serial numbers
serials_row=",Serial"
for ip in "${printer_ips[@]}"; do
  # Fetch the serial number
  echo "Querying serial number for printer: $ip"
  serial=$(snmpget -v2c -c $community $ip $oid_serial | awk -F ': ' '{print $2}')
  
  # Output IP and serial number to console
  echo "Serial number: $serial"
  
  serials_row="$serials_row,$serial"
done

# Prepare the row for counts
counts_row="$(date +"%Y-%m-%d"),$(date +"%H:%M:%S")"
for ip in "${printer_ips[@]}"; do
  # Fetch the page count
  echo "Querying printer: $ip"
  count=$(snmpget -v2c -c $community $ip $oid_pages | awk '{print $4}')
  
  # Output IP and page count to console
  echo "$count"
  
  counts_row="$counts_row,$count"
done

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
    echo "Date,Time,page counts >>>"
    echo "$counts_row"
  } > "$output_directory/$filename"
fi

echo "Totals appended to or written to $filename"

# Export the variables so they are available to the timecalc script
timeend=$(date +%s.%N) #get now's time
export timestart
export timeend
echo "all done"
