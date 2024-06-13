import yaml
from pysnmp.hlapi import *

# Load configuration from the YAML file
def load_config():
    import os
    script_dir = os.path.dirname(os.path.realpath(__file__))
    config_file = os.path.join(script_dir, '../settings.yaml')
    
    with open(config_file, 'r') as file:
        config = yaml.safe_load(file)
    
    return config

config = load_config()
printer_test_oids = config['PrinterTest']

# List of printer models to ignore
import yaml
from pysnmp.hlapi import *

# Load configuration from the YAML file
def load_config():
    import os
    script_dir = os.path.dirname(os.path.realpath(__file__))
    config_file = os.path.join(script_dir, '../settings.yaml')
    
    with open(config_file, 'r') as file:
        config = yaml.safe_load(file)
    
    return config

config = load_config()
printer_test_oids = config['PrinterTest']

# List of printer models to ignore
ignore_models = [
    "Canon MF450 Series",
    "Canon MF741C/743C",
    "Canon LBP226",
    "canon",
    "as400",
    "ibm",
    "yealink",
    "HP ETHERNET",
    "Xerox",
    "SOLID F40",
    "Integrated PrintNet"
]

def is_printer(ip):
    for oid in printer_test_oids:
        errorIndication, errorStatus, errorIndex, varBinds = next(
            getCmd(SnmpEngine(),
                   CommunityData('public', mpModel=0),
                   UdpTransportTarget((ip, 161)),
                   ContextData(),
                   ObjectType(ObjectIdentity(oid)))
        )

        if not errorIndication and not errorStatus:
            for varBind in varBinds:
                if str(varBind[1]):
                    model = str(varBind[1])
                    if oid.endswith("1.3.6.1.2.1.25.3.2.1.3.1"):  # Assuming this OID represents the model
                        print(f"Printer model detected: {model}")

                        # Check if the detected model is in the ignore list
                        if any(ignore_model.lower() in model.lower() for ignore_model in ignore_models):
                            print(f"Model '{model}' is in ignore list, skipping...")
                            return False
                        else:
                            print(f"Model '{model}' is not in ignore list, passing...")
                            return True
    return False

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python findPrintersFilter.py <IP>")
        sys.exit(1)

    ip = sys.argv[1]
    if is_printer(ip):
        print(1)
    else:
        print(0)


def is_printer(ip):
    for oid in printer_test_oids:
        errorIndication, errorStatus, errorIndex, varBinds = next(
            getCmd(SnmpEngine(),
                   CommunityData('public', mpModel=0),
                   UdpTransportTarget((ip, 161)),
                   ContextData(),
                   ObjectType(ObjectIdentity(oid)))
        )

        if not errorIndication and not errorStatus:
            for varBind in varBinds:
                if str(varBind[1]):
                    model = str(varBind[1])
                    if oid.endswith("1.3.6.1.2.1.25.3.2.1.3.1"):  # Assuming this OID represents the model
                        print(f"Printer model detected: {model}")

                        # Check if the detected model is in the ignore list
                        if any(ignore_model.lower() in model.lower() for ignore_model in ignore_models):
                            print(f"Model '{model}' is in ignore list, skipping...")
                            return False
                        else:
                            print(f"Model '{model}' is not in ignore list, passing...")
                            return True
    return False

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python findPrintersFilter.py <IP>")
        sys.exit(1)

    ip = sys.argv[1]
    if is_printer(ip):
        print(1)
    else:
        print(0)
