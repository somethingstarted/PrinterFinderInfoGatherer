# more_python/printer_type.py

from pysnmp.hlapi import *

def snmp_get(ip, oid):
    errorIndication, errorStatus, errorIndex, varBinds = next(
        getCmd(SnmpEngine(),
               CommunityData('public', mpModel=0),
               UdpTransportTarget((ip, 161)),
               ContextData(),
               ObjectType(ObjectIdentity(oid)))
    )
    if errorIndication or errorStatus:
        return None
    else:
        for varBind in varBinds:
            return str(varBind[1])
    return None
def is_color_printer(ip, model):
    # OIDs for checking toner status
    toner_oids = {
        'black': '1.3.6.1.2.1.43.11.1.1.9.1.1',
        'cyan': '1.3.6.1.2.1.43.11.1.1.9.1.2',
        'magenta': '1.3.6.1.2.1.43.11.1.1.9.1.3',
        'yellow': '1.3.6.1.2.1.43.11.1.1.9.1.4'
    }

    is_color_printer_dict = {
        'ECOSYS M3860idn': '0',
        'ECOSYS P3260dn': '0',
        'ECOSYS M6235cidn': '1',
        'Dell B2360dn': '0',
        'KONICA MINOLTA bizhub 360i': '1',
        'KONICA MINOLTA bizhub C558': '1',
        'HP LaserJet MFP M130nw': '0',
        'HP Color LaserJet Pro M454dn': '1',
        'Source Technologies ST9820': '0',
    }

    # If model is recognized in the dictionary, use it to determine if it's a color printer
    if model in is_color_printer_dict:
        return is_color_printer_dict[model] == '1'

    # If the model is not recognized, fall back to checking toner OIDs
    for color in ['cyan', 'magenta', 'yellow']:
        result = snmp_get(ip, toner_oids[color])
        if result is not None and result != 'noSuchInstance':
            return True  # It's a color printer if any color toner is present

    return False  # It's a B/W printer if no color toner is present

