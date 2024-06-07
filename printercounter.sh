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

# Function to get printer model
get_printer_model() {
  local ip="$1"
  local model_oid="1.3.6.1.2.1.25.3.2.1.3.1" # Example OID for printer model; update this to the correct OID
  snmpget -v2c -c $community $ip $model_oid | awk -F ': ' '{print $2}'
}

# Function to get the first successful SNMP response
try_snmp_get() {
  local ip="$1"
  shift
  local oids=("$@")
  for oid in "${oids[@]}"; do
    response=$(snmpget -v2c -c $community $ip $oid 2>/dev/null | awk -F ': ' '{print $2}')
    if [ -n "$response" ]; then
      echo "$response"
      return 0
    fi
  done
  return 1
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

relative_path=$(realpath --relative-to="$(pwd)" "$recent_printers_csv")
echo "Using printers list from $relative_path"


# Read the printer IPs from the CSV file (first column, starting from the second row)
mapfile -t printer_ips < <(tail -n +2 "$recent_printers_csv" | cut -d',' -f1)

# SNMP community string
community="public"

#---------------------------------------------------------------#
#                                                               #
#       OIDS cannot be put in YAML. They must be hardcoded.     #
#                                                               #
#---------------------------------------------------------------#
#                                                               #
#!/bin/bash

# Define OIDs for each printer model
declare -A OIDS
OIDS["HP_BW"]="1.3.6.1.2.1.43.10.2.1.4.1.1"
OIDS["HP_COLOR"]="1.3.6.1.2.1.43.10.2.1.5.1.1"
OIDS["Integrated_BW"]="1.3.6.1.4.1.12345.1.1"
OIDS["Integrated_COLOR"]="1.3.6.1.4.1.12345.1.2"
OIDS["KONICA_BW"]="1.3.6.1.4.1.789.1.1"
OIDS["KONICA_COLOR"]="1.3.6.1.4.1.789.1.2"
OIDS["KYOCERA_BW"]="1.3.6.1.4.1.123.1.1"
OIDS["KYOCERA_COLOR"]="1.3.6.1.4.1.123.1.2"
OIDS["Source_BW"]="1.3.6.1.4.1.456.1.1"
OIDS["Source_COLOR"]="1.3.6.1.4.1.456.1.2"
OIDS["Canon_BW"]="1.3.6.1.4.1.789.2.1"
OIDS["Canon_COLOR"]="1.3.6.1.4.1.789.2.2"

# Function to get printer counts
get_printer_counts() {
    local ip=$1
    local model=$2

    local bw_oid=${OIDS[${model}_BW]}
    local color_oid=${OIDS[${model}_COLOR]}

    if [ -n "$bw_oid" ] && [ -n "$color_oid" ]; then
        bw_count=$(snmpget -v1 -c public "$ip" "$bw_oid" | awk '{print $NF}')
        color_count=$(snmpget -v1 -c public "$ip" "$color_oid" | awk '{print $NF}')
        
        echo "IP: $ip, Model: $model, B/W Count: $bw_count, Color Count: $color_count"
    else
        echo "No OID found for model $model"
    fi
}

# Read CSV and process each line
while IFS=, read -r ip model; do
    # Skip header
    if [[ "$ip" == "IP" ]]; then
        continue
    fi

    get_printer_counts "$ip" "$model" | tee -a printer_audit.log
done < printers.csv                                             #
#                                                               #
#---------------------------------------------------------------#

# Prepare the header for CSV file
header="IP:"
type_row="Date,Time"
model_row="Model"
for ip in "${printer_ips[@]}"; do
  header="$header,$ip,$ip"
  type_row="$type_row,b/w,color"
done

# Prepare the row for serial numbers and page counts
serials_row="Serial"
counts_row="$(date +"%Y-%m-%d"),$(date +"%H:%M:%S")"


for ip in "${printer_ips[@]}"; do
  # Ping the IP address
  echo -n "pinging $ip - "
  if ! ping -c 1 -W 1 "$ip" &> /dev/null; then
    echo "No response..."
    serials_row="$serials_row,"
    counts_row="$counts_row,,"
    model_row="$model_row,"
    continue
  else
    echo  ""
  fi

  # Get printer model
  model=$(get_printer_model "$ip")
  
  echo ">>>>>>>: $ip: $model"
  model_row="$model_row,$model, <-- "


  # Query serial number
  echo -n "  $ip Serial: "
  serial=$(try_snmp_get "$ip" "${oid_serial[@]}")
  serial=$(sanitize_output "$serial")
  echo "$serial"
  serials_row="$serials_row,$serial, <--"

  # Query page counts
  echo -n "  $ip  B/W:  "
  count_bw=$(try_snmp_get "$ip" "${oid_pages_bw[@]}")
  count_bw=$(sanitize_output "$count_bw")
  echo "$count_bw"
  counts_row="$counts_row,$count_bw"

  echo -n "  $ip Color:  "
  count_color=$(try_snmp_get "$ip" "${oid_pages_color[@]}")
  count_color=$(sanitize_output "$count_color")
  echo "$count_color"
  counts_row="$counts_row,$count_color"
done

# Check if the file already exists
if [ -f "$output_directory/$filename" ]; then
  echo "Appending today's totals to the existing CSV file..."
  echo "$counts_row" >> "$output_directory/$filename"
else
  echo "Creating a new CSV file with header, model row, and type row..."
  {
    echo "$(date +"%b %Y"),$header"
    echo ,"$model_row"
    echo ,"$serials_row"
    echo "$type_row"
    echo "$counts_row"
  } > "$output_directory/$filename"
fi

echo "Totals appended to or written to $filename"

# Export the variables so they are available to the timecalc script
timeend=$(date +%s.%N) #get now's time
export timestart
export timeend
echo "all done"
