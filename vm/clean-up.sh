#!/bin/bash

rm bionic-server-cloudimg-amd64.img 
rm vm.xml
virsh destroy hicn
virsh undefine hicn
