#!/bin/bash

## Download and install yq
#sudo wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 -O /usr/local/bin/yq
#sudo chmod +x /usr/local/bin/yq
#yq --version


############################################################################################
#####                       install docker:                                               ##
##                  https://docs.docker.com/engine/install/ubuntu/                        ##
############################################################################################
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo docker run hello-world
#
#
###################################################################################

# Install snmpget and bc
sudo apt install snmp -y
sudo apt install bc -y

sudo apt install exa -y
alias ls=exa

sudo apt install caffeine -y

sudo apt install htop -y

sudo apt install gnome-tweaks -y

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
