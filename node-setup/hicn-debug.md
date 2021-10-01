# hICN Connection Debugging

This document will serve as a resouce for users experiencing problems with setting up stable hICN connectivity between two nodes. Refer to [hicn-config.md](https://github.com/cbmckni/hicn-genomics/blob/master/node-setup/hicn-config.md) for base instructions for establishing connectivity. 

## Config Setup

**All commands should be run with sudo/root permissions.**

For a stable and persistent hICN connection, a *startup-config* file should be created. To do this, add a line `startup-config <FILE>` to the *unix* section of `/etc/vpp/startup.conf`. For example:

```
unix {
  nodaemon
  log /var/log/vpp/vpp.log
  full-coredump
  cli-listen /run/vpp/cli.sock
  gid vpp
  startup-config /etc/vpp/ini.conf
}
# /etc/vpp/ini.conf
# configures an interface for hICN transfers via VPP/DPDK.
```

Here in an example of the contents of a *startup-config* file:

```
$ cat /etc/vpp/ini.conf
set int state TenGigabitEthernet68/0/0 up
create sub TenGigabitEthernet68/0/0 3101
set int state TenGigabitEthernet68/0/0.3101 up
set int ip address TenGigabitEthernet68/0/0.3101 192.168.1.50/24
set ip6 address TenGigabitEthernet68/0/0.3101 ::ffff:c0a8:132/120
hicn punting add prefix c001::/16 intfc TenGigabitEthernet68/0/0.3101 type ip
```

This startup file creates a sub interface, assigns IPv4/v6 addresses, and configures punting with another node with prefix *c001*.

Here is another that configures the other side:

```
$ cat /etc/vpp/ini.conf
set int state TenGigabitEthernet3/0/0 up
create sub TenGigabitEthernet3/0/0 2661
set int state TenGigabitEthernet3/0/0.2661 up
set int ip address TenGigabitEthernet3/0/0.2661 192.168.1.49/24
set ip6 address TenGigabitEthernet3/0/0.2661 ::ffff:c0a8:131/120
hicn face ip add local ::ffff:c0a8:0131 remote ::ffff:c0a8:0132 intfc TenGigabitEthernet3/0/0.2661
hicn fib add prefix c001::/16 face 0
hicn punting add prefix c001::/16 intfc TenGigabitEthernet3/0/0.2661 type ip
```

This config file also creates a face, which is basically a route between the *local* and *remote* interfaces with assigned IPv6 addresses. This configuration establishes one-sided connectivity from the node with the config above to the node with the first config.

To establish bi-directional connectivity, each node needs the following:

### DPDK Compatible Interfaces

Each node needs a DPDK-compatible interface that has been detached from the linux kernel. To do this, use the [dpdk-devbind.py](https://github.com/DPDK/dpdk/blob/main/usertools/dpdk-devbind.py) script.

Examples:
```
To display current device status:
        python dpdk-devbind.py --status
To display current network device status:
        python dpdk-devbind.py --status-dev net
To bind eth1 from the current driver and move to use vfio-pci
        python dpdk-devbind.py --bind=vfio-pci eth1
To unbind 0000:01:00.0 from using any driver
        python dpdk-devbind.py -u 0000:01:00.0
To bind 0000:02:00.0 and 0000:02:00.1 to the ixgbe kernel driver
        python dpdk-devbind.py -b ixgbe 02:00.0 02:00.1
```

To check if an interface has been switched over and being used by VPP, use `sudo vppctl show int`:

```
$ vppctl show int
Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count
TenGigabitEthernet68/0/0          1      up 
TenGigabitEthernet68/0/0.3101     2      up           
local0                            0     down          
memif0/0                          3      up   
```

Each node will need a sub-interface with the appropiate VLAN tag:

```
create sub TenGigabitEthernet68/0/0 3101
set int state TenGigabitEthernet68/0/0.3101 up
```

Finally assign IP addresses to each sub-interface with the appropiate subnet.

The IPv6 should be equivalent to the assigned IPv4. Tools like [this website](https://iplocation.io/ipv4-to-ipv6) may be used to convert the IPv4 to IPv6 notation.

Example: 

```
set int ip address TenGigabitEthernet68/0/0.3101 192.168.1.50/24
set ip6 address TenGigabitEthernet68/0/0.3101 ::ffff:c0a8:132/120
```

### Faces

Each node needs a face added for the *local* and *remote* addresses and local interface. Use the IPv6 addresses. For example: 

`sudo vppctl hicn face ip add local ::ffff:c0a8:0131 remote ::ffff:c0a8:0132 intfc TenGigabitEthernet3/0/0.2661`

Check with `sudo vppctl hicn show`: 

```
$ vppctl hicn show
Forwarder: enabled
....
Faces: 0
 Face 0: type IP local ::ffff:c0a8:131 remote ::ffff:c0a8:132 ipv6 dev TenGigabitEthernet3/0/0.2661
```

### Prefixes

Each node needs a valid prefix:

`sudo vppctl hicn fib add prefix c001::/16 face 0`

Make sure the face # is correct.

### Punting

Each node needs punting to be configured with the appropriate prefix:

`sudo vppctl hicn punting add prefix c001::/16 intfc TenGigabitEthernet68/0/0.3101 type ip`

Other side:

`sudo vppctl hicn punting add prefix c001::/16 intfc TenGigabitEthernet3/0/0.2661 type ip`

hICN connectivity should be established!

## Testing

First test VPP ping:

`sudo vppctl ping 192.168.1.50 source TenGigabitEthernet3/0/0.2661`

Other side:

`sudo vppctl ping 192.168.1.49 source TenGigabitEthernet68/0/0.3101`

Also test the IPv6 addresses.

Next, test hICN ping:

`sudo hicn-ping-server -n c001::/16`

Other side:

`sudo hicn-ping-client -n c001::1 -m 10000`

Finally, if all of that works, test hiperf:

`sudo hiperf -S c001::/64`

Other side:

`sudo hiperf -C c001::1 -W 300`

## Debugging

If there are problems when testing, first check your configuration and make sure all interfaces/addresses/faces/punting/etc exist.

Next, eheck the VPP startup logs to make sure it starts correctly and has all the plugins(hICN, DPDK, etc):

`sudo journalctl -u vpp -f`

You may also want to restart VPP once your *startup-config* files are ready:

`sudo systemctl restart vpp`

Finally, we can trace packets:

memif-input:

```
sudo vppctl show trace
sudo vppctl trace add memif-input 10
sudo vppctl show trace
```

dpdk-input:

```
sudo vppctl show trace
sudo vppctl trace add dpdk-input 10
sudo vppctl show trace
```

Inspect the trace for dropped packets and other errors. 





