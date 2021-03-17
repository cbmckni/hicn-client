#!/bin/bash

echo "Running hicn client"

# Run vpp
echo "Starting vpp..."
/bin/bash /tmp/init.sh &

sleep 2

#HICN client options
ORIGIN_ADDRESS=${ORIGIN_ADDRESS:-"localhost"}
ORIGIN_PORT=${ORIGIN_PORT:-"80"}
CACHE_SIZE=${CACHE_SIZE:-"10000"}
DEFAULT_CONTENT_LIFETIME=${DEFAULT_CONTENT_LIFETIME:-"7200"}
HICN_MTU=${HICN_MTU:-"1300"}
FIRST_IPV6_WORD=${FIRST_IPV6_WORD:-"b001"}
USE_MANIFEST=${USE_MANIFEST:-"true"}
HICN_PREFIX=${HICN_PREFIX:-"http://hicn-http-proxy "}
UDP_TUNNEL_ENDPOINTS=${UDP_TUNNEL_ENDPOINTS:-"198.111.224.199:33567"}
HICN_SERVER=${HICN_SERVER:-"198.111.224.199"} 
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}
NETWORK_DEVICE=${NETWORK_DEVICE:-"tun0"}

# UDP Punting
HICN_LISTENER_PORT=${HICN_LISTENER_PORT:-33567}
TAP_ADDRESS_VPP=192.168.0.2
TAP_ADDRESS_KER=192.168.0.1
TAP_ADDRESS_NET=192.168.0.0/24
TAP_ID=0
TAP_NAME=tap${TAP_ID}

echo "Creating interface..."
vppctl create tap id ${TAP_ID}
vppctl set int state ${TAP_NAME} up
vppctl set interface ip address ${TAP_NAME} ${TAP_ADDRESS_VPP}/24
ip addr add ${TAP_ADDRESS_KER}/24 brd + dev ${TAP_NAME}

# Masquerade all the traffic coming from VPP
iptables -t nat -A POSTROUTING -j MASQUERADE \
  --src ${TAP_ADDRESS_NET} ! \
  --dst ${TAP_ADDRESS_NET} \
  -o ${NETWORK_INTERFACE}
  
echo "Setting up client..."
# Add default route to vpp
vppctl ip route add 0.0.0.0/0 via ${TAP_ADDRESS_KER} ${TAP_NAME}
# Set UDP punting
vppctl hicn punting add prefix ${FIRST_IPV6_WORD}::/16 \
  intfc ${TAP_NAME} type udp4 \
  dst_port ${HICN_LISTENER_PORT}

# Face route and punting
vppctl hicn face udp add \
  src_addr ${TAP_ADDRESS_VPP} port ${HICN_LISTENER_PORT} \
  dst_addr ${HICN_SERVER} port ${HICN_LISTENER_PORT} \
  intfc ${TAP_NAME}
  
vppctl hicn fib add prefix ${FIRST_IPV6_WORD}::/16 face 0

vppctl hicn punting add prefix ${FIRST_IPV6_WORD}::/16 \
  intfc ${TAP_NAME} type udp4 \
  src_port ${HICN_LISTENER_PORT} \
  dst_port ${HICN_LISTENER_PORT}

#Forwarding rules
echo "Adding rules..."
sysctl -w net.ipv4.ip_forward=1

iptables -A FORWARD \
  --in-interface ${NETWORK_INTERFACE} \
  --out-interface ${NETWORK_DEVICE} \
  -j ACCEPT
  
iptables -t nat -A POSTROUTING --out-interface tun0 -j MASQUERADE

# Prevents container from exiting at completion
echo "Done! Exiting..."
bash
