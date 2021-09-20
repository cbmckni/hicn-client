#!/bin/bash

# Usage: ./create-vm.sh <default-password>

if [ $# -eq 0 ]; then
    echo "Usage: ./create-vm.sh <default-password>"
    exit 1
fi

wget -O hicn.img https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img

#qemu-img resize hicn.img 5G

virt-customize -a hicn.img --root-password password:$1

PWD=$(pwd)

cat > vm.xml <<EOF
<domain type='kvm'>
  <name>hicn</name>
  <memory unit='GiB'>4</memory>
  <currentMemory unit='GiB'>4</currentMemory>
  <vcpu>1</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
  </os>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
  <disk type='file' device='disk'>
       <driver name='qemu' type='qcow2'/>
       <source file='${PWD}/hicn.img'/>
       <target dev='vda' bus='virtio'/>
  </disk>
  <interface type='bridge'>
    <source bridge='virbr0'/>
    <model type='virtio'/>
  </interface>
  <serial type='pty'>
    <target port='0'/>
  </serial>
  <console type='pty'>
    <target type='serial' port='0'/>
  </console>
  </devices>
</domain>
EOF

virsh define vm.xml

virsh start hicn

echo "Done! Run 'virsh console hicn' to access VM."

