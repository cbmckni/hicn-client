#!/bin/bash

# Usage: ./gen-router-conf.sh <LOCALINT> <LOCALIP4> <LOCALIP6> <NODELIST> <PREFIX>

# Variables
LOCALINT=$1 # Ex. TenGigabitEthernet3/0/0
LOCALIP4=$2 # Ex. 192.168.1.49
LOCALIP6=$3 # Ex. ::ffff:c0a8:131
NODELIST=$4 # Path to a text file containing IPv6s of all producers.
PREFIX=$5 # Ex. c001::/16

# init node
cat <<EOF > /etc/vpp/ini.conf         
set int state ${LOCALINT} up
set int state ${LOCALINT} up
set int ip address ${LOCALINT} ${LOCALIP4}/24
set ip6 address ${LOCALINT} ${LOCALIP6}/120
EOF

# Set up connections - TODO use URL
FACE=0
while read PRODUCERIP6; do
URL=$(python3 urltool.py) # TODO: add urltool.py 
cat <<EOF >> /etc/vpp/ini.conf         
hicn face ip add local ${LOCALIP6} remote ${PRODUCERIP6} intfc ${LOCALINT}
hicn fib add prefix ${PREFIX} face ${FACE}
hicn punting add prefix ${PREFIX} intfc ${LOCALINT} type ip
EOF
FACE=((FACE++))
done < $NODELIST

