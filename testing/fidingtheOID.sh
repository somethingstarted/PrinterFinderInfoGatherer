#!/bin/bash

# Define the IP address and community string
IP="10.25.5.54"
COMMUNITY="public"  # Replace with the appropriate community string if needed

# List of OIDs to test
OIDS=(
    "1.3.6.1.2.1.1.1.0"  # sysDescr
    "1.3.6.1.2.1.1.2.0"  # sysObjectID
    "1.3.6.1.2.1.1.3.0"  # sysUpTime
    "1.3.6.1.2.1.1.4.0"  # sysContact
    "1.3.6.1.2.1.1.5.0"  # sysName
    "1.3.6.1.2.1.1.6.0"  # sysLocation
    "1.3.6.1.2.1.1.7.0"  # sysServices
    "1.3.6.1.2.1.43.5.1.1.17.1"  # prtGeneralCurrentLocalization
    "1.3.6.1.2.1.43.10.2.1.4.1.1"  # prtInputMediaName
    "1.3.6.1.2.1.43.11.1.1.6.1.1"  # prtMarkerLifeCount
    "1.3.6.1.2.1.43.11.1.1.9.1.1"  # prtMarkerSuppliesLevel
    "1.3.6.1.2.1.43.11.1.1.5.1.1"  # prtMarkerColorantValue
    "1.3.6.1.2.1.43.12.1.1.4.1.1"  # prtMediaPathMaxSpeed
    "1.3.6.1.2.1.43.18.1.1.1.1.1"  # prtAlertIndex
    "1.3.6.1.2.1.43.18.1.1.2.1.1"  # prtAlertSeverityLevel
    "1.3.6.1.2.1.43.18.1.1.3.1.1"  # prtAlertTrainingLevel
    "1.3.6.1.2.1.43.18.1.1.4.1.1"  # prtAlertLocation
    "1.3.6.1.2.1.43.18.1.1.5.1.1"  # prtAlertGroup
    "1.3.6.1.2.1.43.18.1.1.6.1.1"  # prtAlertGroupIndex
    "1.3.6.1.2.1.43.18.1.1.7.1.1"  # prtAlertLocation
    "1.3.6.1.2.1.43.18.1.1.8.1.1"  # prtAlertCode
    "1.3.6.1.2.1.43.19.1.1.1.1.1"  # prtConsoleDisplayBufferIndex
    "1.3.6.1.2.1.43.19.1.1.2.1.1"  # prtConsoleDisplayBufferText
    "1.3.6.1.2.1.43.8.2.1.14.1.1"  # prtCoverStatus
    "1.3.6.1.2.1.43.9.2.1.2.1.1"  # prtInterpreterLangFamily
    "1.3.6.1.2.1.43.9.2.1.3.1.1"  # prtInterpreterLangLevel
    "1.3.6.1.2.1.43.9.2.1.4.1.1"  # prtInterpreterLangVersion
    "1.3.6.1.2.1.43.9.2.1.5.1.1"  # prtInterpreterDescription
    "1.3.6.1.2.1.43.10.2.1.2.1.1"  # prtInputType
    "1.3.6.1.2.1.43.10.2.1.3.1.1"  # prtInputDimUnit
    "1.3.6.1.2.1.43.10.2.1.5.1.1"  # prtInputCapacity
    "1.3.6.1.2.1.43.10.2.1.6.1.1"  # prtInputRemainingCapacity
    "1.3.6.1.2.1.43.11.1.1.7.1.1"  # prtMarkerSuppliesClass
    "1.3.6.1.2.1.43.11.1.1.8.1.1"  # prtMarkerSuppliesType
    "1.3.6.1.2.1.43.11.1.1.9.1.1"  # prtMarkerSuppliesDescription
    "1.3.6.1.2.1.43.12.1.1.2.1.1"  # prtMediaPathMediaSizeUnit
    "1.3.6.1.2.1.43.12.1.1.3.1.1"  # prtMediaPathMaxSpeedPrintUnit
    "1.3.6.1.2.1.43.16.5.1.2.1.1"  # prtConsoleLightDescription
    "1.3.6.1.2.1.43.10.2"          # stack overflow says pages printed 
    "1.3.6.1.2.1.43.10.1.4"        # idk
)

# Iterate through each OID
for OID in "${OIDS[@]}"
do
    #echo "Testing OID: $OID"
    snmpwalk -v 2c -c $COMMUNITY $IP $OID
done
