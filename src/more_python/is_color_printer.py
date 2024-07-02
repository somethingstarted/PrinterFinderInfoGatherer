# more_python/printer_type.py

from pysnmp.hlapi import *

def snmp_get(snmpv1_community, ip, oid):
    errorIndication, errorStatus, errorIndex, varBinds = next(
        getCmd(SnmpEngine(),
               CommunityData(snmpv1_community, mpModel=0),
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
def is_color_printer(ip, model, snmpv1_community):
    # OIDs for checking toner status
    toner_oids = {
        'black': '1.3.6.1.2.1.43.11.1.1.9.1.1',
        'cyan': '1.3.6.1.2.1.43.11.1.1.9.1.2',
        'magenta': '1.3.6.1.2.1.43.11.1.1.9.1.3',
        'yellow': '1.3.6.1.2.1.43.11.1.1.9.1.4'
    }

    # 1 = color, 0 = B/W
    is_color_printer_dict = { 
        'ECOSYS M3860idn': '0',
        'ECOSYS P3260dn': '0',
        'ECOSYS M6235cidn': '1',
        'ECOSYS P3155dn': '0',
        'ECOSYS P3145dn': '0',
        'ECOSYS PA4500x': '0',
        'ECOSYS P2135dn': '0',
        'ECOSYS P2235dw': '0',
        'ECOSYS M3655idn': '0',
        'Dell B2360dn': '0',
        'KONICA MINOLTA bizhub 360i': '0',
        'KONICA MINOLTA bizhub C558': '1',
        'HP LaserJet MFP M130nw': '0',
        'HP Color LaserJet Pro M454dn': '1',
        'Source Technologies ST9820': '0',
        'KONICA MINOLTA bizhub 450i': '0',
        'Source Technologies ST9820': '0',
    }
#to do: if printer model isn't found on here, it needs to add the printer and it's I.P to the a new LOG for investiation

    # If model is recognized in the dictionary, use it to determine if it's a color printer
    if model in is_color_printer_dict:
        return is_color_printer_dict[model] == '1'

    # If the model is not recognized, fall back to checking toner OIDs
    for color in ['cyan', 'magenta', 'yellow']:
        result = snmp_get(snmpv1_community, ip, toner_oids[color])
        if result is not None and result != 'noSuchInstance':
            return True  # It's a color printer if any color toner is present

    return False  # It's a B/W printer if no color toner is present

