# hICN Node Setup

## VPP installation

Install VPP and hICN

```
curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | sudo bash
sudo apt update
sudo apt -y --allow-downgrades install hicn-plugin=20.01-73-release
sudo apt -y --allow-downgrades install vpp-plugin-dpdk=20.01-release
```

Edit the configuration file `/etc/vpp/startup.conf` to enable the VPP
plugin by uncommenting the corresponding `dpdk {...}` section.

Confirm that VPP runs and that the hICN plugin is enabled:

```
$ sudo vpp -c /etc/vpp/startup.conf
vlib_plugin_early_init:361: plugin path /usr/lib/x86_64-linux-gnu/vpp_plugins:/usr/lib/vpp_plugins
[...]
load_one_plugin:189: Loaded plugin: dpdk_plugin.so (Data Plane Development Kit (DPDK))
[...]
load_one_plugin:189: Loaded plugin: hicn_plugin.so (hICN forwarder)
[...]
```

Hit Ctrl-C to stop the process, as we can now run it as a system service:

```
sudo service vpp start
```

## VPP NIC assignment and IP configuration

Towards umich, we use interface enp3s0f1.1603. VPP must be able to use this
interface which requires it to be down (otherwise it is ignored at startup):

`sudo ip link set dev enp1s0f3 down`

*The interface used may be different for other systems.*

The interface must also use the igb_uio driver:

*Usually, the installation of the DPDK plugin will take care of this step, but here is the procedure in case it does not:*

In this case the Linux kernel driver is being used.
```
$ dpdk-devbind --status

Network devices using DPDK-compatible driver
============================================
<none>

Network devices using kernel driver
===================================
0000:01:00.0 'I350 Gigabit Network Connection 1521' if=enp1s0f0 drv=igb unused=igb_uio,uio_pci_generic
0000:01:00.1 'I350 Gigabit Network Connection 1521' if=enp1s0f1 drv=igb unused=igb_uio,uio_pci_generic
0000:01:00.2 'I350 Gigabit Network Connection 1521' if=enp1s0f2 drv=igb unused=igb_uio,uio_pci_generic
0000:01:00.3 'I350 Gigabit Network Connection 1521' if=enp1s0f3 drv=igb unused=igb_uio,uio_pci_generic
[...]
```

```
$ dpdk-devbind --status | grep enp1s0f3
0000:01:00.3 'I350 Gigabit Network Connection 1521' if=enp1s0f3 drv=igb unused=igb_uio,uio_pci_generic
```

Expose the interface to VPP:
```
sudo dpdk-devbind --bind=igb_uio 0000:03:00.1

#or

sudo dpdk-devbind --bind=uio_pci_generic 0000:03:00.1

# Eventually: modprobe uio_pci_generic
```

The interface is now using a DPDK compatible driver!

```
[...]
Network devices using DPDK-compatible driver
============================================
0000:03:00.1 '82599ES 10-Gigabit SFI/SFP+ Network Connection 10fb' drv=igb_uio unused=uio_pci_generic
[...]
```

Make sure to make edits to `/etc/vpp/startup.conf` and restart the service:

```
sudo vim /etc/vpp/startup.conf # uncomment the dpdk section
sudo service vpp restart
```

You should now see the interface in VPP:

```
$ sudo vppctl show int
              Name               Idx    State  MTU (L3/IP4/IP6/MPLS)     Counter          Count
GigabitEthernet1/0/0              1     down         9000/0/0/0
GigabitEthernet1/0/1              2     down         9000/0/0/0
GigabitEthernet1/0/2              3     down         9000/0/0/0
GigabitEthernet1/0/3              4     down         9000/0/0/0
GigabitEthernet6/0/0              7     down         9000/0/0/0
GigabitEthernet6/0/1              8     down         9000/0/0/0
GigabitEthernet6/0/2              9     down         9000/0/0/0
GigabitEthernet6/0/3              10    down         9000/0/0/0
GigabitEthernet8/0/0              11    down         9000/0/0/0
GigabitEthernet8/0/1              12    down         9000/0/0/0
GigabitEthernet8/0/2              13    down         9000/0/0/0
GigabitEthernet8/0/3              14    down         9000/0/0/0
GigabitEthernetc/0/1              15    down         9000/0/0/0
TenGigabitEthernet3/0/0           5     down         9000/0/0/0
TenGigabitEthernet3/0/1           6     down         9000/0/0/0
local0                            0     down          0/0/0/0
```

Now, create a sub-interface for the VLAN:

```
sudo vppctl set int state TenGigabitEthernet3/0/1 up
sudo vppctl create sub TenGigabitEthernet3/0/1 1603
sudo vppctl set int state TenGigabitEthernet3/0/1.1603 up
sudo vppctl set in ip address TenGigabitEthernet3/0/1.1603 10.10.3.20/24
```

The new interface appears in the list of interfaces:

```
TenGigabitEthernet3/0/1.1603      16     up           0/0/0/0       rx packets                    11
                                                                    rx bytes                     748
```

Verify the address:

```
sudo vppctl show int addr
[...]
TenGigabitEthernet3/0/1.1603 (up):
  L3 10.10.3.20/24
[...]
```


Test with `vppctl ping`:

```
$ sudo vppctl ping 10.10.3.10
116 bytes from 10.10.3.10: icmp_seq=1 ttl=64 time=6.6213 ms
```

*You cannot use linux commandline tools when directly binding the interface to VPP. An alternative solution would consist in AF_PACKET interfaces (tap)...*

## Local ICN configuration

Now, test sample hICN applications locally.

Verify hICN plugin is indeed running:

```
$ sudo vppctl hicn show
Forwarder: enabled
  PIT:: max entries:131072, lifetime default: max:20.00
  CS::  max entries:4096, network entries:2048, app entries:2048 (allocated 0, free 2048)
  PIT entries (now): 0
  CS total entries (now): 0, network entries (now): 0
  Forwarding statistics:
    pkts_processed: 0
    pkts_interest_count: 0
    pkts_data_count: 0
    pkts_from_cache_count: 0
    interests_aggregated: 0
    interests_retransmitted: 0
Faces: 0
Strategies:
(0) Static Weights: weights are updated by the control plane, next hop is the one with the maximum weight.
(1) Round Robin: next hop is chosen ciclying between all the available next hops, one after the other.
```

We will install some simple applications to start with.

```
$ sudo apt search hicn | grep memif
[...]
hicn-apps-memif/xenial 20.05-13-release amd64
hicn-apps-memif-dev/xenial 20.05-13-release amd64
hicn-utils-memif/xenial 20.05-13-release amd64
libhicnctrl-memif/xenial 20.05-13-release amd64
libhicnctrl-memif-dev/xenial 20.05-13-release amd64
libhicntransport-memif/xenial 20.05-13-release amd64
libhicntransport-memif-dev/xenial 20.05-13-release amd64
```

*Note that there are usually two versions of the same packages, based on the interface to the hICN forwarder. For VPP, we need to use the `memif` flavour, which designates the shared memory component used for communication between the applications and the forwarder.*

Simply running apt install won't work since we did not install the lastest version of VPP.

```
$ sudo apt install hicn-apps-memif hicn-utils-memif
[...]
The following packages have unmet dependencies:
 hicn-apps-memif : Depends: libhicntransport-memif (>= 20.05) but it is not going to be installed
 hicn-utils-memif : Depends: libhicntransport-memif (>= 20.05) but it is not going to be installed
[...]

$ sudo apt install libhicntransport-memif
[...]
The following packages have unmet dependencies:
 libhicntransport-memif : Depends: libmemif (>= 20.05) but it is not going to be installed
                          Depends: vpp (>= 20.05-release) but 20.01-release is to be installed
[...]
```

Instead, identify the latest version marked as 20.01, which is the VPP version we are using:

```
sudo apt show hicn-utils-memif -a | grep Version
```

We thus need to run the following command:

```
$ sudo apt install libhicntransport-memif=20.01-114-release libhicnctrl-memif=20.01-114-release
$ sudo apt install hicn-apps-memif=20.01-114-release hicn-utils-memif=20.01-114-release
```

### ping

Start a second shell instance and start the ping server:

```
$ sudo hicn-ping-server
```

This has created an applicative face:

```
$ sudo vppctl hicn show
[...]
Faces: 0
 Face 0: type IP local fc00::2 remote fc00::3 ipv6 dev memif0/0  (producer face: CS size 1000, data cached 3)
[...]
```

We take the opportunity to inspect the hICN FIB, which is in fact the IPv6 FIB. We can see the route towards our ping server, whose default IP prefix is b001::/64.

```
$ sudo vppctl show ip6 fib
[...]
b001::/64
  unicast-ip6-chain
  [@0]: dpo-load-balance: [proto:ip6 index:16 buckets:1 uRPF:14 to:[3:180]]
    [0] [@19]: hicn-mw
         Face 0: type IP local fc00::2 remote fc00::3 ipv6 dev memif0/0  (producer face: CS size 1000, data cached 3) weight 0 FIB
[...]
```

Run the ping client:

```
$ sudo hicn-ping-client
start ping
>>> send interest b001::1|0

<<< received object.
<<< round trip: 210 [us]
<<< interest name: b001::1|0
<<< object name: b001::1|0
<<< content object size: 1310 [bytes]

[...]
```

The same is also reflected back on the server side.

### http server

We will now download a file through HTTP/ICN.

We assume a webserver is installed locally:

```
$ wget localhost -qO - | head -n 3

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
```

Let's run the hICN HTTP proxy:

```
$ sudo hicn-http-proxy -SM
Using default prefix http://hicn-http-proxy
Running HTTP/hICN -> HTTP/TCP proxy.
Parameters:
        Origin address: 127.0.0.1
        Origin port: 80
        Producer cache size: 50000
        hICN MTU: 1500
        Default content lifetime: 7200;
        Producer Prefix: http://hicn-http-proxy
        Prefix first word: b001
        Use manifest: 1
        N Threads: 1
```

We see that the webserver is using a subprefix of the default b001::/16, which is mapped from the producer prefix referenced in the previous output, `http://hicn-http-proxy`.

```
icn@nwn:~$ sudo vppctl show ip6 fib
[sudo] password for icn:
ipv6-VRF:0, fib_index:0, flow hash:[src dst sport dport proto ] epoch:0 flags:none locks:[mpls:4, default-route:1, hicn:2, nat-hi:1, ]
[...]
b001:0:9cb7:275d::/64
  unicast-ip6-chain
  [@0]: dpo-load-balance: [proto:ip6 index:22 buckets:1 uRPF:17 to:[0:0]]
    [0] [@19]: hicn-mw
         Face 2: type IP local fc00::a remote fc00::b ipv6 dev memif0/2  (producer face: CS size 48, data cached 0) weight 0 FIB
         Face 3: type IP local fc00::c remote fc00::d ipv6 dev memif0/3  (producer face: CS size 0, data cached 0) weight 0 FIB
[...]
```

Download the file over hICN:

```
$ sudo higet -O - http://hicn-http-proxy/index.html | head -n 3
Using name http://hicn-http-proxy/index.html and name first word b001
06-10 12:16:59.812  5107  5107 I GET http://hicn-http-proxy/index.html [b001::9cb7:275d:d84f:432f:e6a2:33e7|0] duration: 1617 [usec] 11595 [bytes]


<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
```

## Persistant configuration

Before further configuration, we will apply these settings to persist across VPP restarts:

```
sudo mkdir /usr/share/vpp/scripts

sudo tee "/usr/share/vpp/scripts/internet2-nwn.txt" > /dev/null <<'EOF'
set int state TenGigabitEthernet3/0/1 up
create sub TenGigabitEthernet3/0/1 1603
set int state TenGigabitEthernet3/0/1.1603 up
set int ip address TenGigabitEthernet3/0/1.1603 10.10.3.20/24
EOF
```

Add this line to the unix section of VPP configuration file `/etc/vpp/startup.conf`:

```
exec /usr/share/vpp/scripts/internet2-nwn.txt
```

*This line usually goes at the beginning of the file.*

Restart VPP and confirm this is working:

```
sudo service vpp restart # sudo systemctl restart vpp

sleep 1
sudo vppctl show int | grep 1603
```

### Remote ICN configuration

Let's now move to a two-node setup.

We will now run the http proxy on NODE1, and the client on NODE2.

We recommand the usage of hICN with IPv6, so as to be able to use the IPv6 address space for naming. We will thus add an IPv6 address to the interface (and do the same on the remote node):
```
sudo vppctl set ip6 address TenGigabitEthernet3/0/1.1603 2001::10:10:3:20/16
```

Ping test:
```
sudo vppctl ping 2001::10:10:3:10
76 bytes from 2001::10:10:3:10: icmp_seq=1 ttl=63 time=5.8931 ms
```

We now need to add three configuration elements:
1.  A face from NODE2 to NODE1 that will materialize the adjacency.
2.  A route insructing the forwarder to use this face for prefixes starting with b001::/16 say (the forwarder will perform Longest Prefix Match as usual since we leverage the IPv6 FIB).
3.  Enable punting of hICN packets for the considered interface, which means the forwarder needs to be aware that b001::/16 indeed corresponds to an hICN prefix, and is not simply regular IPv6 traffic. Without this step, the router will behave as a regular IPv6 equipment, things will seem to work but hICN functionalities will not be executed locally.

1. Face (needs to use IPv6):

```
sudo vppctl hicn face ip add local 2001::10:10:3:20 remote 2001::10:10:3:10 intfc TenGigabitEthernet3/0/1.1603
```

The command returns the ID of the newly added face, in this case 0.

2. Route:

```
sudo vppctl hicn fib add prefix b001::/16 face 0
```

*An IP route as follows will not work as the IP address rewrite of hICN will not be applied:*

```
sudo vppctl ip route add b001::/16 via 2001::10:10:3:10 TenGigabitEthernet3/0/1.1603
```

3. Punting has to be configured on both the NODE1 and NODE2:

NODE1:

```
sudo vppctl hicn punting add prefix b001::/16 intfc TenGigabitEthernet3/0/1.1603 type ip
```

NODE2:

```
sudo vppctl hicn punting add prefix b001::/16 intfc TenGigabitEthernet3/0/1.3132 type ip
```

We now validate that HTTP/hICN traffic works, and is indeed going through the hICN path:

```
sudo hicn-ping-client 
start ping
>>> send interest b001::1|0

<<< received object. 
<<< round trip: 6430 [us]
<<< interest name: b001::1|0
<<< object name: b001::1|0
<<< content object size: 1310 [bytes]

sudo vppctl hicn show
[...]
Forwarder: enabled
  PIT:: max entries:131072, lifetime default: max:20.00
  CS::  max entries:4096, network entries:2048, app entries:2048 (allocated 0, free 2048)
  PIT entries (now): 8
  CS total entries (now): 2, network entries (now): 2
  Forwarding statistics:
    pkts_processed: 44
    pkts_interest_count: 42
    pkts_data_count: 2
    pkts_from_cache_count: 0
    interests_aggregated: 0
    interests_retransmitted: 0
Faces: 0
 Face 0: type IP local 2001::10:10:3:20 remote 2001::10:10:3:10 ipv6 dev TenGigabitEthernet3/0/1.1603
Strategies:
(0) Static Weights: weights are updated by the control plane, next hop is the one with the maximum weight.
(1) Round Robin: next hop is chosen ciclying between all the available next hops, one after the other.
```

We can now run the http proxy in the server and get the page through hICN.

NODE2:

```
sudo hicn-http-proxy -SM
```

NODE1:

```
$ sudo higet -O - http://hicn-http-proxy/index.html | head -n 3
Using name http://hicn-http-proxy/index.html and name first word b001
06-10 12:16:59.812  5107  5107 I GET http://hicn-http-proxy/index.html [b001::9cb7:275d:d84f:432f:e6a2:33e7|0] duration: 1617 [usec] 11595 [bytes]


<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
```

## Additional notes

You can find useful information within commands like:
```
sudo vppctl hicn ?
```

You can also run an interactive shell through simply:
```
sudo vppctl
```

*In this version, faces are fully handled by hICN and do not rely on VPP adjacencies, so there is no need to create the face from UMICH to NWN. This will change from VPP 20.05.*
