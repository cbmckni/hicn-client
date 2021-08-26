#!/bin/sh

curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | bash

apt-get update                                                              &&  \
    apt-get -y install git nano wget iperf3 traceroute iputils-ping             &&  \
    apt-get -y install iptables iproute2                                        &&  \
    apt-get -y --allow-downgrades -o Dpkg::Options::=--force-confnew install        \
    vpp=20.01-release                         \
    vpp-plugin-core=20.01-release             \
    vpp-plugin-dpdk=20.01-release             \
    libvppinfra=20.01-release                 \
    hicn-apps-memif=20.01-114-release         \
    hicn-utils-memif=20.01-114-release        \
    libhicntransport-memif=20.01-114-release  \
    libhicnctrl-memif=20.01-114-release       \
    hicn-plugin=20.01-73-release \
    libhicn=20.01-114-release \
    apache2
