import os
import csv
import subprocess
from datetime import datetime
import pysnmp.hlapi as snmp
import re

# Import the new script
from more_python.printer_type import is_color_printer

# The rest of your current script remains unchanged

# Get the start time
timestart = datetime.now()

# Set the output directory to be the same location as the script, or the current working directory
script_dir = os.path.dirname(os.path.abspath(__file__))
output_directory = os.path.join(script_dir, "printerCounterOUTPUT")

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
    model_oid = "1.3.6.1.2.1.25.3.2.1.3.1"
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
    bw_oids = get_matching_oids(OIDS_bw, model, default_oid)
    color_oids = get_matching_oids(OIDS_color, model, default_oid)

    bw_count = try_snmp_get(ip, bw_oids)
    color_count = try_snmp_get(ip, color_oids)

    return bw_count if bw_count is not None else "", color_count if color_count is not None else ""

def get_matching_oids(oid_dict, model, default):
    # Normalize the model string by converting to lowercase and removing spaces
    normalized_model = model.lower().replace(" ", "")
    
    for keys in oid_dict:
        # If keys is not a tuple, convert it to a single-element tuple for consistency
        if not isinstance(keys, tuple):
            keys = (keys,)
        
        # Check each possible match in the tuple
        for key in keys:
            # Normalize the key string by converting to lowercase and removing spaces
            normalized_key = key.lower().replace(" ", "")
            
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

# Main loop and other parts remain unchanged

# Get the printer model and check if it is a color printer
for ip in printer_ips:
    model = get_printer_model(ip)
    isColorPrinter = is_color_printer(ip)
    print(f"Printer IP: {ip}, Model: {model}, Is Color Printer: {isColorPrinter}")

# The rest of your script continues...
