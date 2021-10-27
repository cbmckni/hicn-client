#!/bin/bash

INDEX=0
while read node; do
  echo "Node: $node"
  YAML="hicn-${node}.yaml"
  NAME="hicn-${node}"
  PVC="${2}-${INDEX}"
  cat <<EOF > "$YAML"
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ${NAME}-producer
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: ${NAME}-producer
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${node}
      domain:
        devices:
          filesystems:
            - name: hicn-pvc
              virtiofs: {}
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinitdisk
              disk:
                bus: virtio
          interfaces:
          - name: default
            masquerade: {}
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      volumes:
        - name: containerdisk
          containerDisk:
            image: cbmckni/hicn-disk
        - name: cloudinitdisk
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
        - name: hicn-pvc
          persistentVolumeClaim:
          claimName: ${PVC}
            
EOF
  kubectl create -f $YAML
  echo "VMs for node ${node} submitted."
  virtctl start $NAME-producer
  echo "VMs $NAME started."
done < $1