from pysnmp.hlapi import *

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
    "HP",
    "Xerox",
    "Integrated"
]

# OIDs to test for printers
printer_test_oids = [
    "1.3.6.1.2.1.25.3.2.1.3.1"  # Example OID for printer model
]

# False means not a printer, or ignore printer
# True means is a printer
def is_printer(ip):
    model = None
    
    # Check the OIDs to detect the model
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
                    if oid.endswith("1.3.6.1.2.1.25.3.2.1.3.1"):  # Assuming this OID represents the model
                        model = str(varBind[1])
                        break

    # Ensure model has a value before using it
    if model:
        print(f"Printer model detected: {model}")

        match_count = sum(model.lower().count(ignore_model.lower()) for ignore_model in ignore_models)
        if match_count > 0:
            print(f"match_count: {match_count}")
            return False  # Ignore this printer

    # If model is not in ignore list or not detected, proceed with OID checks
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
                    return True  # OID check passed, it is a printer

    return False  # Defaulting to not a printer if no model or OID check passed

# Example usage
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
