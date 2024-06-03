#!/bin/bash

## Download and install yq
#sudo wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 -O /usr/local/bin/yq
#sudo chmod +x /usr/local/bin/yq
#yq --version

## Install snmpget and bc
#sudo apt install snmp -y
#sudo apt install bc -y

# Check if SNMP is installed
echo "Checking if SNMP is installed..."
if ! command -v snmpget &> /dev/null; then
    echo "SNMP is not installed. Please install SNMP or run 'sudo bash computersetup.sh'"
    exit 1
else
    echo "SNMP is installed. continuing..."
fi

# Check if bc is installed
echo "Checking if bc is installed..."
if ! command -v bc &> /dev/null; then
    echo "bc is not installed. Please install bc or run 'sudo bash computersetup.sh'"
    exit 1
else
    echo "bc is installed. continuing..."
fi

# Check if yq is installed
echo "Checking if yq is installed..."
if ! command -v yq &> /dev/null; then
    echo "yq is not installed. Please install yq to parse YAML files."
    exit 1
else
    echo "yq is installed. continuing..."
fi
