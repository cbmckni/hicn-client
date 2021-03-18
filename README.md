# **hICN-Genomics**

This repository contains code generated in collaboration between Cisco and Clemson University funded upder Cisco Research Proposal "Exposing the Potential of Hybrid ICN (hICN) for Genomics" (ProjectID: 1380311).  This README is divided into 3 sections:  

1. Pulling data from an hICN testbed using an hICN client container.
2. Publishing data into an hICN testbed.
3. Case study of publishing 3000+ indexed genomes in to the testbed.

# **PULLING DATA FROM hICN TESTBED**

## hICN Client

This is the specification and documentation for a HICN client container. End users can use this image to pull data from a HICN network to any container-compatible platform of their choosing.

## Configure

Set the name of the hicn client image and the port it should use:

`export IMAGE_NAME="hicn-client-image"`

`export NAME="hicn-client"`

`export PORT="33567"`

`export HICN_ENDPOINT="198.111.224.199:33567"`

*The default SHICN_ENDPOINT IP/port is a server intended for testing hicn client connectivity. It may or may not be serving content at the time of your testing.*

*Use "cbmckni/hicn-client" for $IMAGE_NAME if you do not wish to build and push your own image.* [Image](https://hub.docker.com/r/cbmckni/hicn-client)

## Build

Build the hicn-client image with:

`docker build -t $IMAGE_NAME .`

*For non-local deployments, your newly built image must be uploaded to a container registry.* [Docs](https://docs.docker.com/docker-hub/)

## Deployment

### Local

To run the container on any system locally, first set up a volume to hold peristent data:

`docker volume create persistent-storage`

Run the image using the volume:

```
docker run --mount source=persistent-data,target=/workspace     \
           --cap-add=NET_ADMIN                                  \
           --device=/dev/vhost-net                              \
           --device=/dev/net/tun                                \
           --sysctl net.ipv4.ip_forward=1                       \
           -p $PORT:$PORT/udp                                   \
           -e HICN_LISTENER_PORT=$PORT                          \
           -e UDP_TUNNEL_ENDPOINTS=198.111.224.199:33567        \
           -d                                                   \
           -it                                                  \
           --name $NAME $IMAGE_NAME
```

#### Deletion

Stop the container:

`docker container stop $NAME`

Delete the container:

`docker container rm $NAME`

(Optional) Delete the persistent storage volume:

`docker volume rm persistent-storage`


### Kubernetes

To deploy to a Kubernetes cluster, you must have a bound PVC for the container to store persistent data. 

#### (Optional) Create NFS Persistent Volume Claim

We use Helm to create a Dynamic NFS volume provisioner, then use [hicn-pvc.yaml](https://github.com/cbmckni/hicn-genomics/blob/master/kubernetes/hicn-pvc.yaml) to request a Read-Write-Many(RWX) PVC.

Update Helm's repositories(similar to `apt-get update)`:

`helm repo update`

Next, install a NFS provisioner onto the K8s cluster to permit dynamic provisoning for 50Gi of persistent data:

`helm install kf stable/nfs-server-provisioner --set=persistence.enabled=true,persistence.storageClass=standard,persistence.size=52Gi`

Check that the `nfs` storage class exists:

`kubectl get sc nfs`

```
# kubectl get sc nfs
NAME                 PROVISIONER                               RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs                  cluster.local/kf-nfs-server-provisioner   Delete          Immediate           true                   9s
```

Next, deploy a 50Gi Persistant Volume Claim(PVC) to the cluster:

`kubectl create -f hicn-pvc.yaml`

Check that the PVC was deployed successfully:

`kubectl get pvc hicn-pvc`

```
# kubectl get pvc hicn-pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
hicn-pvc   Bound    pvc-c82b0804-e55e-4841-a2e6-c839678bb38d   50Gi       RWX            nfs            35s
```

#### Create and Access Kubernetes Deployment

Deploy the client container to a Kubernetes cluster:

`kubectl create -f hicn-client.yaml`

If using a PVC not named `hicn-pvc`, Be sure to edit the file to specify the correct PVC.

Show pod:

`kubectl get pods --selector=app=hicn-client`

```
# kubectl get pods --selector=app=hicn-client
NAME                           READY   STATUS    RESTARTS   AGE
hicn-client-5ff45fd887-xt88m   1/1     Running   0          5m31s
```

To access the pod:

`kubectl exec -ti hicn-client-5ff45fd887-xt88m -- /bin/bash`

Persistent data store is located at `/workspace` by default!

#### Deletion

Delete the deployment:

`kubectl delete -f hicn-client.yaml`

(Optional) Delete the persistent volume claim:

`kubectl delete pvc hicn-pvc`

(Optional) Delete the NFS storage provisoner:

`helm uninstall kf`

## Usage

Run the setup script:

`/hicn/run-setup`

```
# ./run-setup.sh
Running hicn client
Starting vpp...
Configure VPP
Creating interface...
tap0
Setting up client...
Face id: 0
Adding rules...
net.ipv4.ip_forward = 1
Done! Exiting...
```

Use the `higet` command to pull a dataset. Examples:

`higet -O - http://hicn-http-proxy/index.html`

`higet http://hicn-http-proxy/SRR5139397_1.fastq.gz`

`higet http://hicn-http-proxy/4754.tgz`

# **PUBLISHING DATA INTO THE hICN TESTBED**

To install and configure hICN for publishing data or other applications, see [hicn-config.md](https://github.com/cbmckni/hicn-genomics/blob/master/node-setup/hicn-config.md).


# **3000+ GENOMES USE CASE**
We have initiated a pilot genomics content use case of hICN.  Two named content compendia were created: Named Indexed Genome Compendia and Named Raw RNAseq Compendia.

*Named Indexed Genome Compendia.* In collaboration with Washington State University, Clemson University, Tennessee Tech University, and Cisco, we have downloaded 3,042 published genomes (i.e., FASTA) and gene coordinate (e.g. GTF) files from ENSEMBL or NCBI using Pynome software (https://github.com/SystemsGenetics/pynome).  The genomes were preprocessed and indexed for input into hisat2, kallisto, and salmon workflows.  Then the files were named for publication into an hICN system.  For specific version of the genome mapping software used for indexing, please see:  https://github.com/SystemsGenetics/pynome/blob/master/Dockerfile. 

These genomes represent a snapshot of all published genomes and are used by researchers across biology domains (and the planet) as reference DNA sequences for identifying genetic and epigenetic differences between individuals of major species, quantifying gene expression, and and many more applications that require data-intensive computing.

In aggregate, these named indexed genome files sum to 7.8 Terabytes (uncompressed).  These datasets are an asset to any researcher doing genomics for several reasons.  First, the researcher (or application) need only to provide the taxonomy "species" unique identifier to pull the dataset.  Second, the dataset has been pre-indexed, which is computationally expensive, for several popular genomics applications including hisat2, kallisto, and salmon. Third, the datasets can be positioned near compute using the hICN allowing for efficient data transfers.

The genome datasets were named by a standard Taxonomy ID (e.g., Human = Homo sapiens = 9606).  Currently, they are pulled as a compressed archive, but we will parse into specific indexed datasets for retrieval. We are also developing a REST API service on top of a metadata engine with dataset URLs for searching for named dataset groups and dynamic dataset publication into an hICN system. Here is an example of the named file structure for these genome files: 
/BIOLOGY/Genome/ENSEMBL/
[genus]_[species]{_[infraspecific_name]}-[assemply_name]
[genus]_[species]{_[infraspecific_name]}-[assemply_name].{index extension e.g. ht2}
[genus]_[species]{_[infraspecific_name]}-[assemply_name].gff3
[genus]_[species]{_[infraspecific_name]}-[assemply_name].fasta
[genus]_[species]{_[infraspecific_name]}-[assemply_name].gtf
[genus]_[species]{_[infraspecific_name]}-[assemply_name],Spice_Sites.txt

A subset of popular genomes (e.g. human) have been published in the hICN testbed for benchmarking purposes and insertion into genomics workflows.  They can be accessed using instructions from this repository and the taxonomy ID.  We intend to split these files into specific named indexes in the near future.  

*Named Raw RNAseq Compendia.*  In addition to the reference genomes, we have created a naming strategy for all RNAseq data sets from the NCBI-SRA archive.  This database contains over 50 petabytes of data and  is experiencing geometric growth (https://trace.ncbi.nlm.nih.gov/Traces/sra/).  We have named RNAseq files around the Taxonomy ID and SRA run identifier.  Here is an example of the naming structure of a human kidney RNAseq dataset:
/BIOLOGY/SRA/9605/9606/NaN/RNA-Seq/ILLUMINA/TRANSCRIPTOMIC/PAIRED/Kidney/PRJNA359795/SRP095950/SRX2458154/SRR5139398/1 > SRR5139398_1.fastq.gz

We have published several datasets for workflow insertion and performance testing:

1. NCBI-SRA-Animal_Example:(0.16 TB; 36X2 SRA Samples; Human kidney): https://www.ncbi.nlm.nih.gov/bioproject/359795
Transcriptome sequencing (RNA-Seq) of non-tumor kidney tissues from 36 patients undergoing nephrectomy for exploring the metabolic mechanism of sorafenib and identifying the major transcriptional regulation factors in sorafenib metabolism in kidney
2. NCBI-SRA-Plant_Example: (1.14 TB; 475X2 SRA Samples; Rice leaves):
Rice gene expression in heat stress and dehydration stress - time series
https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA301554

We intend to expand these offering to all primate data as well as trigger mechanisms to automatically publish and name a dataset from NCBI-SRA and NASA GeneLab into hICN using data URIs.

