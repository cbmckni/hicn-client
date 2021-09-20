#!/bin/bash

rm hicn.img 
rm vm.xml
virsh destroy hicn
virsh undefine hicn
