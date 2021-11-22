#!/bin/bash

# Usage: ./gen-router-conf.sh <LOCALINT> <LOCALIP6> <ROUTERIP6> <PREFIX>

# Variables
LOCALINT=$1 # Ex. TenGigabitEthernet3/0/0
LOCALIP6=$2 # Ex. ::ffff:c0a8:131
ROUTERIP6=$3 # Ex. ::ffff:c0a8:132
PREFIX=$4 # Ex. c001::/16


# Set up connection to $ROUTERIP6 - TODO use URL
URL=$(python3 urltool.py) # TODO: add urltool.py 
cat <<EOF >> /etc/vpp/ini.conf         
hicn face ip add local ${LOCALIP6} remote ${ROUTERIP6} intfc ${LOCALINT}
hicn fib add prefix ${PREFIX} face 0
hicn punting add prefix ${PREFIX} intfc ${LOCALINT} type ip
EOF