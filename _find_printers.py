import os
import subprocess
import yaml
from datetime import datetime, timedelta
from pysnmp.hlapi import *

# Import is_printer function from the new script
from more_python.findPrintersFilter import is_printer

# Define OIDs for different printer data
SERIAL_OIDS = [
    ".1.3.6.1.2.1.43.5.1.1.17.1",  # General printer serial number OID
    ".1.3.6.1.4.1.2385.1.1.5.1.1.1",  # Konica Minolta specific OID (example)
    ".1.3.6.1.4.1.1347.41.1.1.1.1.4.0"  # Ecosys specific OID (example)
]
MODEL_OID = ".1.3.6.1.2.1.1.1.0"  # OID for the printer model
HOSTNAME_OID = ".1.3.6.1.2.1.1.5.0"  # OID for the printer hostname

# Get the directory of the script
script_dir = os.path.dirname(os.path.realpath(__file__))

# Assuming the YAML file is in the same directory as the script
config_file = os.path.join(script_dir, 'settings.yaml')

# Output directory
output_dir = os.path.join(script_dir, 'foundprinters')
os.makedirs(output_dir, exist_ok=True)

# Load configuration from the YAML file
with open(config_file, 'r') as file:
    config = yaml.safe_load(file)

debug_mode = config['debug']
subnets = config['subnets']
known_printers = config['knownprinters']
date_filename_offset = -config['DateFilenameOffset']

# Determine the base date
if config['debug_date']:
    base_date = datetime.strptime(f"01-{config['debug_MM_YYYY']}", "%d-%m-%Y")
else:
    base_date = datetime.now()

# Calculate the adjusted date based on offset
adjusted_date = base_date + timedelta(days=date_filename_offset)
adjusted_month_year = adjusted_date.strftime("%Y-%m")

# Get current month and year for file naming
output_file = os.path.join(output_dir, f"printers_{adjusted_month_year}.csv")
print(">>>>>")
print(f">>>>>        FILE NAME: printers_{adjusted_month_year}.csv")
print(">>>>>")

# Get current month name for log file naming
log_file = os.path.join(output_dir, f"log_{adjusted_month_year}.txt")

# Today's log file
todays_log = os.path.join(output_dir, "TodaysLog.txt")

# Clear today's log file
with open(todays_log, 'w'):
    pass

# Log the start of the script
with open(log_file, 'a') as log, open(todays_log, 'a') as tlog:
    start_time = datetime.now().strftime("%I:%M %p - %d %B %Y")
    log.write(f"***** {start_time} - starting script\n")
    tlog.write(f"***** {start_time} - starting script\n")

# Function to get data from the printer using SNMP
def get_printer_data(ip):
    serial = ""
    model = ""
    hostname = ""

    for oid in SERIAL_OIDS:
        errorIndication, errorStatus, errorIndex, varBinds = next(
            getCmd(SnmpEngine(),
                   CommunityData('public', mpModel=0),
                   UdpTransportTarget((ip, 161)),
                   ContextData(),
                   ObjectType(ObjectIdentity(oid)))
        )

        if errorIndication:
            continue
        elif errorStatus:
            continue
        else:
            for varBind in varBinds:
                serial = str(varBind[1])
                if serial:
                    break
        if serial:
            break

    errorIndication, errorStatus, errorIndex, varBinds = next(
        getCmd(SnmpEngine(),
               CommunityData('public', mpModel=0),
               UdpTransportTarget((ip, 161)),
               ContextData(),
               ObjectType(ObjectIdentity(MODEL_OID)))
    )

    if not errorIndication and not errorStatus:
        for varBind in varBinds:
            model = str(varBind[1])

    errorIndication, errorStatus, errorIndex, varBinds = next(
        getCmd(SnmpEngine(),
               CommunityData('public', mpModel=0),
               UdpTransportTarget((ip, 161)),
               ContextData(),
               ObjectType(ObjectIdentity(HOSTNAME_OID)))
    )

    if not errorIndication and not errorStatus:
        for varBind in varBinds:
            hostname = str(varBind[1])

   
    serial = serial.replace(",", " ")
    model = model.replace(",", " ")
    hostname = hostname.replace(",", " ")

    max_length = 40
    return serial, model[:max_length], hostname

# Function to check if a printer is already in the CSV file
def is_printer_in_csv(ip):
    with open(output_file, 'r') as file:
        return any(line.startswith(f"{ip},") for line in file)

# Function to scan an IP address and update the CSV content
def scan_ip(current_ip):

    print(f"{current_ip} - polling...", end="")
        # Skip if IP is x.x.x.1 or x.x.x.255
    if current_ip.endswith('.1') or current_ip.endswith('.255'):
        print(f"\033[K", end="\r")
        print(f"{current_ip} - skipped", end="\n")
        return
    response = subprocess.run(['ping', '-c', '1', '-W', '1', current_ip], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if response.returncode != 0:
        print(f"\033[K", end="\r")
        print(f"{current_ip} - ?")
        with open(todays_log, 'a') as tlog:
            tlog.write(f"{current_ip} - ?\n")
        return

    serial, model, hostname = get_printer_data(current_ip)
    #print('', end='')
    print(f"{current_ip},{model},{serial},{hostname}", end="\n")

    if is_printer(current_ip):
        
        with open(todays_log, 'a') as tlog:
            if not serial:
                tlog.write(f"{current_ip} - no serial - ?\n")
                print(f"{current_ip}")
            else:
                tlog.write(f"{current_ip} - {model} - {serial} - {hostname}\n")

        if serial and not is_printer_in_csv(current_ip):
            with open(output_file, 'a') as file:
                file.write(f"{current_ip},{model},{serial},{hostname}\n")
    else:
        with open(todays_log, 'a') as tlog:
            tlog.write(f"{current_ip} - {model} - {serial} - {hostname} - not a printer\n")

# Initialize CSV file with headers if it doesn't exist
if not os.path.isfile(output_file):
    with open(output_file, 'w') as file:
        file.write("ip,model,serial,hostname\n")

# Function to generate IPs in a subnet
def generate_ips_in_subnet(subnet):
    import ipaddress
    network = ipaddress.IPv4Network(subnet, strict=False)
    for ip in network.hosts():
        yield str(ip)

# Main logic to decide which IPs to scan
if debug_mode:
    for current_ip in known_printers:
        scan_ip(current_ip)
    with open(todays_log, 'a') as tlog:
        tlog.write(f"Results saved to {output_dir}\n")
else:
    for subnet in subnets:
        with open(log_file, 'a') as log, open(todays_log, 'a') as tlog:
            log.write(f"{datetime.now().strftime('%H:%M:%S')} starting subnet {subnet}\n")
            tlog.write(f"{datetime.now().strftime('%H:%M:%S')} starting subnet {subnet}\n")

        for current_ip in generate_ips_in_subnet(subnet):
            scan_ip(current_ip)

        with open(log_file, 'a') as log, open(todays_log, 'a') as tlog:
            log.write(f"{datetime.now().strftime('%H:%M:%S')} finished subnet {subnet}\n")
            tlog.write(f"{datetime.now().strftime('%H:%M:%S')} finished subnet {subnet}\n")
            tlog.write(f"Results saved to {output_dir} for subnet {subnet}\n")

# Log the end of the script
with open(log_file, 'a') as log, open(todays_log, 'a') as tlog:
    end_time = datetime.now().strftime("%I:%M %p - %d %b")
    log.write(f"{end_time} - entire script finished\n")
    tlog.write(f"{end_time} - entire script finished\n")

print(f"All subnets scanned. Results saved to {output_dir}")
