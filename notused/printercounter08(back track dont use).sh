#!/bin/bash

timestart=$(date +%s.%N)

# Set the output directory to be the same location as the script, or the current working directory
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
output_directory="$script_dir/printerCounterOUTPUT"

# Define the filename with the requested naming scheme
filename="totals_$(date +"%Y_%m").csv"
logfile="$output_directory/todayslog.txt"

# Ensure the output directory exists
mkdir -p "$output_directory"

# Clear the log file at the start of each run
: > "$logfile"

# Redirect all output to the logfile
exec > >(tee -a "$logfile") 2>&1

# Function to sanitize and truncate output
sanitize_output() {
  local input="$1"
  local truncated=$(echo "$input" | cut -c1-64)
  local sanitized=$(echo "$truncated" | tr -cd 'a-zA-Z0-9 ')
  echo "$sanitized"
}

# Default OID
default_oid="1.3.6.1.2.1.43.10.2.1.4.1.1"

# Define OIDs for each printer model
declare -A OIDS_bw
OIDS_bw["HP"]="1.3.6.1.2.1.43.10.2.1.4.1.1"
OIDS_bw["Integrated"]="1.3.6.1.4.1.12345.1.1"
OIDS_bw["KONICA"]="1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.1.2 1.3.6.1.4.1.1347.42.3.1.1.1.1.1"
OIDS_bw["KYOCERA"]="1.3.6.1.4.1.1347.43.10.1.1.12.1.1 1.3.6.1.4.1.1347.42.3.1.2.1.1.1.1 1.3.6.1.4.1.1347.42.2.1.1.1.6.1.6"
OIDS_bw["Source"]="null"
OIDS_bw["Canon"]="1.3.6.1.4.1.789.2.1"

declare -A OIDS_color
OIDS_color["HP"]="1.3.6.1.2.1.43.10.2.1.5.1.1"
OIDS_color["Integrated"]="1.3.6.1.4.1.12345.1.2"
OIDS_color["KONICA"]="1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.2.2"
OIDS_color["KYOCERA"]="1.3.6.1.4.1.1347.43.10.1.1.13.1.1"
OIDS_color["Source"]="null"
OIDS_color["Canon"]="1.3.6.1.4.1.789.2.2"

# Function to try multiple OIDs
try_snmp_get_multiple() {
  local ip=$1
  shift
  local oids=("$@")
  local result=""
  
  for oid in "${oids[@]}"; do
    if [[ "$oid" != "null" ]]; then
      result=$(snmpget -v1 -c public "$ip" "$oid" 2>/dev/null | awk '{print $NF}')
      if [ -n "$result" ]; then
        break
      fi
    fi
  done

  # Use default OID if no result found
  if [ -z "$result" ]; then
    result=$(snmpget -v1 -c public "$ip" "$default_oid" | awk '{print $NF}')
  fi
  
  echo "$result"
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
foundprinters_dir="$( cd "$script_dir/foundprinters" && pwd )"
csv_file="$foundprinters_dir/printers_${year}-${month}.csv"

# Check if the CSV file exists
if [[ ! -f "$csv_file" ]]; then
  echo "CSV file not found: $csv_file"
  exit 1
fi

# Create the output CSV file and add the header
output_csv="$output_directory/$filename"
echo "IP,Model,Serial,B/W Count,Color Count" > "$output_csv"

# Read CSV and process each line
while IFS=, read -r ip model serial hostname; do
  # Skip header
  if [[ "$ip" == "IP" ]]; then
    continue
  fi

  echo "Processing IP: $ip, Model: $model"

  # Query serial number
  echo -n "  $ip Serial: "
  serial=$(try_snmp_get_multiple "$ip" "$serial")
  serial=$(sanitize_output "$serial")
  echo "$serial"
  
  # Query page counts
  echo -n "  $ip B/W: "
  count_bw=$(try_snmp_get_multiple "$ip" ${OIDS_bw[$model]})
  count_bw=$(sanitize_output "$count_bw")
  echo "$count_bw"
  
  echo -n "  $ip Color: "
  count_color=$(try_snmp_get_multiple "$ip" ${OIDS_color[$model]})
  count_color=$(sanitize_output "$count_color")
  echo "$count_color"
  
  # Append to output CSV
  echo "$ip,$model,$serial,$count_bw,$count_color" >> "$output_csv"
done < "$csv_file"

timeend=$(date +%s.%N)
timetaken=$(echo "$timeend - $timestart" | bc)

echo "Time taken: $timetaken seconds"
