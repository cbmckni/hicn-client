# SR-IOV with hICN

This will serve as a guide to install and configure the Single Root I/O Virtualization Plug-In for Kubernetes clusters.

Use these [instructions](https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin/edit/master/docs/vf-setup.md) as a reference.

## Installing Virtual Functions 

First, get root/sudo access to a node of the cluster that has one of the supported network cards:

* **Intel i40e Driver**
	* Intel® Ethernet Controller X722 
	* Intel® Ethernet Controller X710
* **Intel ixgbe Driver** 
	* Intel® Ethernet Controller 82599
	* Intel® Ethernet Controller X520
	* Intel® Ethernet Controller X540
	* Intel® Ethernet Controller x550
	* Intel® Ethernet Controller X552
	* Intel® Ethernet Controller X553

To list the network cards run:

```
lspci | egrep -i --color 'network|ethernet'`
```

```
$ lspci | egrep -i --color 'network|ethernet'
21:00.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5]
21:00.1 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5]
62:00.0 Ethernet controller: Intel Corporation I350 Gigabit Network Connection (rev 01)
62:00.1 Ethernet controller: Intel Corporation I350 Gigabit Network Connection (rev 01)
```


Next, match the PCI address of the NIC you elect with the device name using `sudo lshw -c network -businfo`

```
$ sudo lshw -c network -businfo
Bus info          Device           Class          Description
=============================================================
pci@0000:21:00.0  enp33s0f0        network        MT27800 Family [ConnectX-5]
pci@0000:21:00.1  enp33s0f1        network        MT27800 Family [ConnectX-5]
pci@0000:62:00.0  eno1             network        I350 Gigabit Network Connection
pci@0000:62:00.1  eno2             network        I350 Gigabit Network Connection
```

Match the devide with the directory in `sys/class/net/`:

```
$ ls /sys/class/net/
cali29360de70a9  cali67e3c145905  calia2ef2d6f056  calieb9488a60cb  califd3a763cb78  eno1  eno2  enp33s0f0  enp33s0f1  lo  tunl0
```

Use that as $PF_NAME below.

### Creating VFs with sysfs
First select a compatible NIC on which to create VFs and record its name (shown as PF_NAME below). 

#### Intel

To create 8 virtual functions run:
```
echo 8 > /sys/class/net/${PF_NAME}/device/sriov_numvfs
```

Example:

```
echo 8 > /sys/class/net/enp33s0f0/device/sriov_numvfs
echo 8 > /sys/class/net/enp33s0f1/device/sriov_numvfs
```

To check that the VFs have been successfully created run:

```
lspci | grep "Virtual Function"
``` 

This method requires the creation of VFs each time the node resets. This can be handled automatically by placing the above command in a script that is run on startup such as `/etc/rc.local`.

#### Mellanox

Install [Mellanox Management Tools](http://www.mellanox.com/page/management_tools):

```
wget https://www.mellanox.com/downloads/MFT/mft-4.17.0-106-x86_64-deb.tgz
tar -xvf mft-4.17.0-106-x86_64-deb.tgz
cd mft-4.17.0-106-x86_64-deb/
sudo ./install.sh
```

Start with `sudo mst start`:

```
$ sudo mst start
Starting MST (Mellanox Software Tools) driver set
Loading MST PCI module - Success
Loading MST PCI configuration module - Success
Create devices
Unloading MST PCI module (unused) - Success
```

Locate the HCA device on the desired PCI slot

```
$ sudo mst status
MST modules:
------------
    MST PCI module is not loaded
    MST PCI configuration module loaded

MST devices:
------------
/dev/mst/mt4119_pciconf0         - PCI configuration cycles access.
                                   domain:bus:dev.fn=0000:21:00.0 addr.reg=88 data.reg=92 cr_bar.gw_offset=-1
                                   Chip revision is: 00
```

Enable SR-IOV

```
$ sudo mlxconfig -d /dev/mst/mt4119_pciconf0 set SRIOV_EN=1 NUM_OF_VFS=8

Device #1:
----------

Device type:    ConnectX5
Name:           MCX516A-CCA_Ax
Description:    ConnectX-5 EN network interface card; 100GbE dual-port QSFP28; PCIe3.0 x16; tall bracket; ROHS R6
Device:         /dev/mst/mt4119_pciconf0

Configurations:                              Next Boot       New
         SRIOV_EN                            False(0)        True(1)
         NUM_OF_VFS                          0               8

 Apply new Configuration? (y/n) [n] : y
Applying... Done!
-I- Please reboot machine to load new configurations.
```

Reboot with `reboot`.

Once you are back in, create VFs:

```
# echo 4 > /sys/class/net/enp33s0f0/device/sriov_numvfs
```

**Must be root to run this, sudo will not work.**

Finally, check for the VFs:

```
# lspci | grep Mellanox
21:00.0 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5]
21:00.1 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5]
21:00.2 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function]
21:00.3 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function]
21:00.4 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function]
21:00.5 Ethernet controller: Mellanox Technologies MT27800 Family [ConnectX-5 Virtual Function]
```

