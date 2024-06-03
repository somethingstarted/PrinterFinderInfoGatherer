import os
import csv
import datetime
import yaml
import subprocess
import sys
from pysnmp.hlapi import SnmpEngine, CommunityData, UdpTransportTarget, ContextData, ObjectType, ObjectIdentity, getCmd

# Get the directory where the script is being run
script_dir = os.path.dirname(os.path.realpath(__file__))
base_dir = os.path.join(script_dir, 'foundprinters')
if not os.path.exists(base_dir):
    os.makedirs(base_dir)

# Define the file path and name
current_month = datetime.datetime.now().strftime("%Y_%m")
file_name = f"foundprinters_{current_month}.csv"
file_path = os.path.join(base_dir, file_name)

# Load configuration from YAML file
config_file = os.path.join(script_dir, 'subnets.yaml')
with open(config_file, 'r') as file:
    config = yaml.safe_load(file)

debug_mode = config.get('debug', False)
subnets = config.get('subnets', [])
known_printers = config.get('knownprinters', [])

# Define OIDs for different printer data
SERIAL_OIDS = [
    ".1.3.6.1.2.1.43.5.1.1.17.1",
    ".1.3.6.1.4.1.2385.1.1.5.1.1.1",
    ".1.3.6.1.4.1.1347.41.1.1.1.1.4.0"
]
MODEL_OID = ".1.3.6.1.2.1.1.1.0"

# Function to get data from the printer using SNMP
def get_printer_data(ip):
    serial = "?"
    model = "?"

    for oid in SERIAL_OIDS:
        error_indication, error_status, error_index, var_binds = next(
            getCmd(SnmpEngine(),
                   CommunityData('public', mpModel=0),
                   UdpTransportTarget((ip, 161)),
                   ContextData(),
                   ObjectType(ObjectIdentity(oid)))
        )
        if not error_indication and not error_status:
            serial = str(var_binds[0][1])
            if serial:
                break

    error_indication, error_status, error_index, var_binds = next(
        getCmd(SnmpEngine(),
               CommunityData('public', mpModel=0),
               UdpTransportTarget((ip, 161)),
               ContextData(),
               ObjectType(ObjectIdentity(MODEL_OID)))
    )
    if not error_indication and not error_status:
        model = str(var_binds[0][1])

    return serial, model

# Function to check if a printer is already in the CSV file
def is_printer_in_csv(ip, csv_data):
    for row in csv_data:
        if row[0] == ip:
            return True
    return False

# Function to read existing data from CSV
def read_csv(file_path):
    data = []
    if os.path.exists(file_path):
        with open(file_path, mode='r') as file:
            csv_reader = csv.reader(file)
            data = list(csv_reader)
    return data

# Function to write data to CSV
def write_csv(file_path, data):
    with open(file_path, mode='w', newline='') as file:
        csv_writer = csv.writer(file)
        csv_writer.writerows(data)

# Main logic to scan IP addresses and update CSV
def scan_ip_range(ip_range):
    csv_data = read_csv(file_path)
    if not csv_data:
        csv_data.append(["ip", "model", "serial"])

    for ip in ip_range:
        print(f"{ip} - ...", end="\r")
        sys.stdout.flush()

        serial, model = get_printer_data(ip)
        if serial == "?" and model == "?":
            print(f"{ip} - ?")
        else:
            print(f"{ip} - {serial} - {model}")
            if not is_printer_in_csv(ip, csv_data):
                csv_data.append([ip, model, serial])

    write_csv(file_path, csv_data)

# Generate list of IPs to scan
def generate_ip_list(subnets):
    ip_list = []
    for subnet in subnets:
        result = subprocess.run(['prips', subnet], stdout=subprocess.PIPE)
        ip_list.extend(result.stdout.decode().splitlines())
    return ip_list

# Execute scanning based on debug mode
if debug_mode:
    scan_ip_range(known_printers)
else:
    ip_list = generate_ip_list(subnets)
    scan_ip_range(ip_list)

print(f"Results saved to {base_dir}")
