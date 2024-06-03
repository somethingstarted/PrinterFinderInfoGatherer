#!/bin/bash

timestart=$(date +%s.%N)

# Function to sanitize and truncate output
sanitize_output() {
  local input="$1"
  # Truncate to first 64 characters
  local truncated=$(echo "$input" | cut -c1-64)
  # Remove unwanted characters, allow only a-zA-Z0-9-_() and spaces
  local sanitized=$(echo "$truncated" | tr -cd 'a-zA-Z0-9 ')
  echo "$sanitized"
}




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
oid_pages_bw=( "1.3.6.1.2.1.43.10.2.1.4.1.1" )
oid_pages_color=( "1.3.6.1.2.1.43.10.2.1.4.1.2" )
oid_serial=( "1.3.6.1.2.1.43.5.1.1.17.1" )

# Prepare the header for CSV file
header="IP:"
type_row="Date,Time"
for ip in "${printer_ips[@]}"; do
  header="$header,$ip,$ip"
  type_row="$type_row,b/w,color"
done

# Prepare the row for serial numbers
serials_row="Serial"

for ip in "${printer_ips[@]}"; do
  echo "Querying serial number for printer: $ip"
  serial=$(snmpget -v2c -c $community $ip $oid_serial | awk -F ': ' '{print $2}')
  serial=$(sanitize_output "$serial")
  echo "Serial number: $serial"
  serials_row="$serials_row,$serial"
done

# Prepare the row for counts
counts_row="$(date +"%Y-%m-%d"),$(date +"%H:%M:%S")"
for ip in "${printer_ips[@]}"; do
  # Fetch the page count for black/white
  echo "Querying black/white page count for printer: $ip"
  count_bw=$(snmpget -v2c -c $community $ip $oid_pages_bw | awk -F ': ' '{print $2}')
  count_bw=$(sanitize_output "$count_bw")
  echo "Black/White page count: $count_bw"
  counts_row="$counts_row,$count_bw"

  # Fetch the page count for color
  echo "Querying color page count for printer: $ip"
  count_color=$(snmpget -v2c -c $community $ip $oid_pages_color | awk -F ': ' '{print $2}')
  count_color=$(sanitize_output "$count_color")
  echo "Color page count: $count_color"
  counts_row="$counts_row,$count_color"
done


# Merge counts_row_bw and counts_row_color
counts_row="$counts_row_bw,$counts_row_color"

# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
output_directory="$script_dir/printerCounterOUTPUT"

# Define the filename with the requested naming scheme
filename="totals_$(date +"%Y_%m").csv"

# Ensure the output directory exists
mkdir -p "$output_directory"

# Check if the file already exists
if [ -f "$output_directory/$filename" ]; then
  echo "Appending today's totals to the existing CSV file..."
  echo "$counts_row" >> "$output_directory/$filename"
else
  echo "Creating a new CSV file with header and type row..."
  {
    echo ",$header"
    echo ",$serials_row"
    echo ",$type_row"
    echo "$counts_row"
  } > "$output_directory/$filename"
fi

echo "Totals appended to or written to $filename"

# Export the variables so they are available to the timecalc script
timeend=$(date +%s.%N) #get now's time
export timestart
export timeend
echo "all done"
