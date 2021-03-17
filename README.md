# hicn-client

This is the specification and documnetation for a HICN client container. End users can use this image to pull data from a HICN network to any container-compatible platform of their choosing.

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

We use Helm to create a Dynamic NFS volume provisioner, then use [hicn-pvc.yaml](https://github.com/cbmckni/hicn-client/blob/master/hicn-client.yaml) to request a Read-Write-Many(RWX) PVC.

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




