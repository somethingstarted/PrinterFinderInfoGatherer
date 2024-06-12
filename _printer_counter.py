import os
import csv
import subprocess
from datetime import datetime
import pysnmp.hlapi as snmp
import re
import yaml

# Assuming the YAML file is in the same directory as the script
script_dir = os.path.dirname(os.path.realpath(__file__))
config_file = os.path.join(script_dir, 'settings.yaml')

# Get the start time
timestart = datetime.now()

from more_python.is_color_printer import is_color_printer

# Set the output directory to be the same location as the script, or the current working directory
output_directory = os.path.join(script_dir, "printerCounterOUTPUT")

# Load the YAML configuration
with open(config_file, 'r') as file:
    config = yaml.safe_load(file)

debug = config.get('debug', False)
known_printers = config.get('knownprinters', [])

# Define the filename with the requested naming scheme
filename = f"totals_{datetime.now():%Y_%m}.csv"
logfile = os.path.join(output_directory, "todayslog.txt")

# Ensure the output directory exists
os.makedirs(output_directory, exist_ok=True)

# Clear the log file at the start of each run
with open(logfile, "w"):
    pass

def sanitize_output(input_str):
    truncated = input_str[:64]
    sanitized = ''.join(e for e in truncated if e.isalnum() or e.isspace())
    return sanitized

def get_printer_model(ip):
    model_oid = "1.3.6.1.2.1.25.3.2.1.3.1"  # Example OID for printer model; update this to the correct OID
    model = snmp_get(ip, model_oid)
    return model if model is not None else ""

def snmp_get(ip, oid):
    errorIndication, errorStatus, errorIndex, varBinds = next(
        snmp.getCmd(snmp.SnmpEngine(),
                    snmp.CommunityData('public'),
                    snmp.UdpTransportTarget((ip, 161)),
                    snmp.ContextData(),
                    snmp.ObjectType(snmp.ObjectIdentity(oid)))
    )
    if errorIndication:
        return None
    elif errorStatus:
        return None
    else:
        for varBind in varBinds:
            return varBind.prettyPrint().split('=')[-1].strip()
    return None

def get_printer_counts(ip, model):
    is_color = is_color_printer(ip, model)  # Ensure model is passed

    bw_oids = get_matching_oids(OIDS_bw, model, default_oid)
    bw_count = try_snmp_get(ip, bw_oids)
    print(f" {ip} bw_count: {bw_count")

    color_count = ""
    if is_color:
        color_oids = get_matching_oids(OIDS_color, model, default_oid)
        color_count = try_snmp_get(ip, color_oids)

    return bw_count if bw_count is not None else "", color_count if color_count is not None else ""


def get_matching_oids(oid_dict, model, default):
    # Normalize the model string by converting to lowercase and removing spaces
    normalized_model = model.lower().replace(" ", "")
    
    for keys in oid_dict:
        # Split keys by comma and iterate over each possible match
        for key in keys.split(','):
            # Normalize the key string by converting to lowercase and removing spaces
            normalized_key = key.strip().lower().replace(" ", "")
            
            if normalized_key in normalized_model:
                # Return the list of OIDs, excluding any "null" entries
                return [oid for oid in oid_dict[keys] if oid != "null"]
    
    # If no match is found, return the default OID
    return [default]

def try_snmp_get(ip, oids):
    for oid in oids:
        response = snmp_get(ip, oid)
        if response:
            return response
    return None

# Get the current year and month
current_year = datetime.now().year
current_month = datetime.now().month

# Format the expected file name
foundPrintersCSV = f"printers_{current_year:04d}-{current_month:02d}.csv"
foundprinters_dir = os.path.join(os.path.dirname(__file__), "foundprinters")
echo = f"searching: {foundprinters_dir}"
expected_file_path = os.path.join(foundprinters_dir, foundPrintersCSV)

# Initialize printer_ips
printer_ips = []

# Check if the expected file exists
if debug:
    print("Debug mode is ON. Skipping file check.")
    # Example of what printer_ips might be in debug mode, replace with actual debug data if available
    printer_ips = known_printers
else:
    print(echo)
    if os.path.exists(expected_file_path):
        print(f"Using printers list from {expected_file_path}")
        # Read the printer IPs from the CSV file (first column, starting from the second row)
        with open(expected_file_path, newline='') as csvfile:
            print(os.getcwd())
            reader = csv.reader(csvfile)
            printer_ips = [row[0] for row in list(reader)[1:]]
    else:
        print(f"ln120: can't open ({foundPrintersCSV}) in {foundprinters_dir}")
        exit(1)

#---------------------------------------------------------------#
#       TODO: put in YAML. They must be hardcoded.              #
#---------------------------------------------------------------#

OIDS_bw = {
    "HP": ["null"],
    "Integrated": ["1.3.6.1.4.1.12345.1.1"],
    "KONICA, minolta, bizhub": ["1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.1.2", "1.3.6.1.4.1.1347.42.3.1.1.1.1.1"], #good so far
    "ecosys, kyocera": ["1.3.6.1.4.1.1347.43.10.1.1.12.1.1", "1.3.6.1.4.1.1347.42.3.1.2.1.1.1.1", "1.3.6.1.4.1.1347.42.2.1.1.1.6.1.6"], #not good
    "Source": ["null"],
    "Canon": ["1.3.6.1.4.1.789.2.1"]
}

OIDS_color = {
    "HP": ["1.3.6.1.2.1.43.10.2.1.5.1.1"],
    "Integrated": ["1.3.6.1.4.1.12345.1.2"],
    "KONICA, minolta, bizhub": ["1.3.6.1.4.1.18334.1.1.1.5.7.2.2.1.5.2.2"],
    "ecosys, kyocera": ["1.3.6.1.4.1.1347.43.10.1.1.13.1.1"],
    "Source": ["null"],
    "Canon": ["1.3.6.1.4.1.789.2.2"]
}

oid_serial = [
    "1.3.6.1.2.1.43.5.1.1.17.1"
]

default_oid = "1.3.6.1.2.1.43.10.2.1.4.1.1"

# Prepare the header for CSV file
header = "IP:"
model_row = "Model"
type_row = "Date,Time"

for ip in printer_ips:
    header += f",{ip},{ip}"
    type_row += ",b/w,color"

# Prepare the row for serial numbers and page counts
serials_row = "Serial"
counts_row = f"{datetime.now():%Y-%m-%d},{datetime.now():%H:%M:%S}"

for ip in printer_ips:
    # Ping the IP address
    response = subprocess.run(['ping', '-c', '1', '-W', '1', ip], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if response.returncode != 0:
        print(f"pinging {ip} - No response...")
        serials_row += ","
        counts_row += ",,"
        model_row += ","
        continue
    else:
        print(f"pinging {ip} - ")

    # Get printer model
    model = get_printer_model(ip)
    print(f">>>>>>>: {ip}: {model}")
    model_row += f",{model},"

    # Query serial number
    print(f"  {ip} Serial: ", end='')
    serial = try_snmp_get(ip, oid_serial)
    serial = sanitize_output(serial) if serial is not None else ""
    print(serial)
    serials_row += f",{serial}, <--"

    # Get printer counts
    count_bw, count_color = get_printer_counts(ip, model)

    # Append counts to counts row
    counts_row += f",{count_bw},{count_color}"


# Check if the file already exists
output_file = os.path.join(output_directory, filename)
if os.path.exists(output_file):
    print("Appending totals to CSV...")
    with open(output_file, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(counts_row.split(','))
else:
    print("Creating new CSV...")
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow([f"{datetime.now():%b %Y}"] + header.split(','))
        writer.writerow([''] + model_row.split(','))
        writer.writerow([''] + serials_row.split(','))
        writer.writerow(type_row.split(','))
        writer.writerow(counts_row.split(','))

print(f"Totals appended to or written to {filename}")

# Get the end time
timeend = datetime.now()
elapsed_time = (timeend - timestart).total_seconds()
print(f"All done in {elapsed_time} seconds")
