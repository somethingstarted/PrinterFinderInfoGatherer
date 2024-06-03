#!/bin/bash

# Get the directory of the script
script_dir=$(dirname "$(readlink -f "$0")")

# Define OIDs for different printer data
SERIAL_OIDS=(
    ".1.3.6.1.2.1.43.5.1.1.17.1"  # General printer serial number OID
    ".1.3.6.1.4.1.2385.1.1.5.1.1.1"  # Konica Minolta specific OID (example)
    ".1.3.6.1.4.1.1347.41.1.1.1.1.4.0"  # Ecosys specific OID (example)
)
MODEL_OID=".1.3.6.1.2.1.1.1.0"  # OID for the printer model
HOSTNAME_OID=".1.3.6.1.2.1.1.5.0"  # OID for the printer hostname

# Assuming the YAML file is in the same directory as the script
config_file="$script_dir/settings.yaml"  # Renamed from subnets.yaml to settings.yaml

# Output directory
output_dir="$script_dir/foundprinters"
mkdir -p "$output_dir"  # Create the directory if it doesn't exist

# Get current month and year for file naming
current_month_year=$(date +"%Y-%m")
output_file="$output_dir/printers_$current_month_year.csv"

# Get current month name for log file naming
current_month_name=$(date +"%B_%Y")
log_file="$output_dir/log_$current_month_name.txt"

# Today's log file
todays_log="$output_dir/TodaysLog.txt"

# Clear today's log file
> "$todays_log"

# Log the start of the script
echo "***** $(date +"%I:%M %p - %d %B %Y") - starting script" | tee -a "$log_file" "$todays_log"

# Load configuration from the YAML file
debug_mode=$(yq eval '.debug' "$config_file")
subnets=($(yq eval '.subnets[]' "$config_file"))
known_printers=($(yq eval '.knownprinters[]' "$config_file"))
printer_test_oids=($(yq eval '.PrinterTest[]' "$config_file"))
printer_test_threshold=$(yq eval '.PrinterTestThreshold' "$config_file")

# Function to get data from the printer using SNMP
get_printer_data() {
    local ip=$1
    local serial=""
    local model=""
    local hostname=""

    # Get serial number
    for oid in "${SERIAL_OIDS[@]}"; do
        serial=$(snmpget -v1 -c public "$ip" "$oid" 2>/dev/null | awk -F ': ' '{print $2}' | tr -d '"')
        if [[ -n "$serial" ]]; then
            break
        fi
    done

    # Get model
    model=$(snmpget -v1 -c public "$ip" "$MODEL_OID" 2>/dev/null | awk -F ': ' '{print $2}' | tr -d '"')

    # Get hostname
    hostname=$(snmpget -v1 -c public "$ip" "$HOSTNAME_OID" 2>/dev/null | awk -F ': ' '{print $2}' | tr -d '"')

    echo "$serial" "$model" "$hostname"
}

# Function to check if a printer is already in the CSV file
is_printer_in_csv() {
    local ip=$1
    grep -q "^$ip," "$output_file"
    return $?
}

# Function to test if an IP is a printer based on multiple OIDs
is_printer() {
    local ip=$1
    local oid
    local response_count=0

    for oid in "${printer_test_oids[@]}"; do
        response=$(snmpget -v1 -c public "$ip" "$oid" 2>/dev/null | awk -F ': ' '{print $2}' | tr -d '"')
        if [[ -n "$response" ]]; then
            ((response_count++))
        fi
    done

    local total_oids=${#printer_test_oids[@]}
    local required_responses=$((total_oids * printer_test_threshold / 100))

    if ((response_count >= required_responses)); then
        return 0  # Is a printer
    else
        return 1  # Not a printer
    fi
}

# Function to scan an IP address and update the CSV content
scan_ip() {
    local current_ip=$1
    local printer_data
    local serial model hostname
    local result_line

    # Print the current IP being polled
    echo -ne "$current_ip - polling...\r"

    # Ping the IP to check if it's reachable
    if ! ping -c 1 -W 1 "$current_ip" &>/dev/null; then
        result_line="$current_ip - ?"
    else
        # Get printer data
        printer_data=$(get_printer_data "$current_ip")
        serial=$(echo "$printer_data" | awk '{print $1}')
        model=$(echo "$printer_data" | awk '{print $2}')
        hostname=$(echo "$printer_data" | awk '{print $3}')

        # Check if the IP is a printer
        if is_printer "$current_ip"; then
            if [[ -z "$serial" ]]; then
                result_line="$current_ip - ?"
            else
                result_line="$current_ip - $model - $serial - $hostname"
                if ! is_printer_in_csv "$current_ip"; then
                    echo "$current_ip,$model,$serial,$hostname" >> "$output_file"
                fi
            fi
        else
            result_line="$current_ip - $model - $serial - $hostname - not a printer"
        fi
    fi

    # Remove the last two lines
    echo -ne "\033[2A\033[2K"  # Move up two lines and clear them
    # Print the result line and update the progress
    echo "$result_line" | tee -a "$todays_log"
    scanned_ips=$((scanned_ips + 1))
    echo -ne "$current_ip - polling...\n"
    echo "$scanned_ips / $total_ips IPs scanned - subnets left: $remaining_subnets"
}

# Initialize CSV file with headers if it doesn't exist
if [[ ! -f "$output_file" ]]; then
    echo "ip,model,serial,hostname" > "$output_file"
fi

# Function to generate IPs in a subnet
generate_ips_in_subnet() {
    local subnet=$1
    IFS=. read -r i1 i2 i3 i4 <<<"${subnet%/*}"
    for i in $(seq 1 254); do
        if [[ "$i" -ne 1 && "$i" -ne 255 ]]; then
            echo "$i1.$i2.$i3.$i"
        fi
    done
}

# Function to update the progress line
update_progress() {
    scanned_ips=$((scanned_ips + 1))
    remaining_subnets=$((total_subnets - scanned_subnets))
    echo -ne "\033[2K\r"  # Clear the line before printing the progress
    echo -ne "$scanned_ips / $total_ips IPs scanned - subnets left: $remaining_subnets"
}

# Main logic to decide which IPs to scan
scanned_ips=0
total_ips=0
total_subnets=${#subnets[@]}
scanned_subnets=0
remaining_subnets=$total_subnets

# Calculate total IPs across all subnets
for subnet in "${subnets[@]}"; do
    ips_in_subnet=($(generate_ips_in_subnet "$subnet"))
    total_ips=$((total_ips + ${#ips_in_subnet[@]}))
done

if [[ "$debug_mode" == "true" ]]; then
    # Scan known printers
    total_ips=${#known_printers[@]}
    for current_ip in "${known_printers[@]}"; do
        scan_ip "$current_ip"
    done
    echo "Results saved to $output_dir" | tee -a "$todays_log"
else
    # Scan each subnet
    for subnet in "${subnets[@]}"; do
        echo "$(date +"%H:%M:%S") starting subnet $subnet" | tee -a "$log_file" "$todays_log"
        ips_in_subnet=($(generate_ips_in_subnet "$subnet"))
        total_ips=$((total_ips + ${#ips_in_subnet[@]}))
        for current_ip in "${ips_in_subnet[@]}"; do
            scan_ip "$current_ip"
        done
        echo "$(date +"%H:%M:%S") finished subnet $subnet" | tee -a "$log_file" "$todays_log"
        echo "Results saved to $output_dir for subnet $subnet" | tee -a "$todays_log"
        scanned_subnets=$((scanned_subnets + 1))
        update_progress
    done
fi

# Log the end of the script
echo "$(date +"%I:%M %p -
