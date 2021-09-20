# hICN VM Orchestration with KubeVirt 

This is a collection of tools for orchestrating hICN VMs on Kubernetes and other cloud platforms

Installing dependencies, building, and deploying the VMs will be covered.

## Installation

First, install dependencies:
 - [kubectl](https://kubernetes.io/docs/tasks/tools/)
 - [virtctl](https://kubevirt.io/user-guide/operations/virtctl_client_tool/)
 - [kvm](https://www.tecmint.com/install-kvm-on-ubuntu/)
*Some tools may be missing. A simple search will reveal installation docs for missing tools.*

Make sure kubectl is configured properly with the Kubernetes cluster of your choosing.

## Deploy a hICN VM

To deploy a VM to a Kubernetes cluster using KubeVirt:

List running VMs: `kubectl get vms`

Edit the [hicn-vm.yaml](https://github.com/cbmckni/hicn-genomics/blob/master/vm/hicn-vm.yaml) file if needed.

If there is already a vm with the name `hicnvm`, change the `name:` and `kubevirt.io/domain:` fields to something unique.

Deploy the VM: `kubectl create -f hicn-vm.yaml`

Start the VM: `virtctl start <vm-name>`

Get a console: `virtctl console <vm-name>`

Use the default password set for the VM with login `root`.

### Clean Up

Stop VM with: `virtctl stop <vm-name>`

Delete VM with: `kubectl delete -f hicn-vm.yaml`

## Build NDN-DPDK VM

To add software to the container disk, a new build must be done. 

First, run the script [create-vm.sh](https://github.com/cbmckni/hicn-genomics/blob/master/vm/create-vm.sh) with your desired default root password: `./create-vm <password>`

*The default password may be specified at deployment using UserData.*

This script does the following:

 - Downloads the Ubuntu 20.04 cloud image.
 - Sets the default root password for the image.
 - Creates a VM definition XML file.
 - Starts the VM.

After the script has finished, run `virsh console hicn` to access the VM. 

Use the login `root` and the password you specified.

After you get a console, copy and paste the [install-hicn.sh](https://github.com/cbmckni/hicn-genomics/blob/master/vm/install-hicn.sh) script into the VM, then run it.

That will install all the NDN-DPDK dependencies and any other software you wish to add.

After the script has finished, exit the VM and stop it with `virsh stop hicn`.

You should now have a stopped VM and the file `hicn.img` in your current directory.

To copy the file into a docker container, build the [Dockerfile](https://github.com/cbmckni/hicn-genomics/blob/master/vm/Dockerfile): `docker build -t <user-name>/hicn-disk .`

Once the container is built, upload it to DockerHub:

`docker login`

`docker push <user-name>/hicn-disk`

Now your hICN container disk can be pulled and deployed!

### Clean Up

To clean up everything, use the script [clean-up.sh](https://github.com/cbmckni/hicn-genomics/blob/master/vm/clean-up.sh).

`./clean-up.sh`

**This will delete the VM and the .img file. Make sure all progress has been pushed to DockerHub!**

