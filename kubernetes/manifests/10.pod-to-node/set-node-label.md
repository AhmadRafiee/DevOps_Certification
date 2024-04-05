Add a label to a node
List the nodes in your cluster, along with their labels:
```
kubectl get nodes --show-labels
```
The output is similar to this:
```
NAME      STATUS    ROLES    AGE     VERSION        LABELS
worker0   Ready     <none>   1d      v1.13.0        ...,kubernetes.io/hostname=worker0
worker1   Ready     <none>   1d      v1.13.0        ...,kubernetes.io/hostname=worker1
worker2   Ready     <none>   1d      v1.13.0        ...,kubernetes.io/hostname=worker2
```
Choose one of your nodes, and add a label to it:
```
kubectl label nodes <your-node-name> disktype=ssd
```
where <your-node-name> is the name of your chosen node.

Verify that your chosen node has a disktype=ssd label:
```
kubectl get nodes --show-labels
```
The output is similar to this:
```
NAME      STATUS    ROLES    AGE     VERSION        LABELS
worker0   Ready     <none>   1d      v1.13.0        ...,disktype=ssd,kubernetes.io/hostname=worker0
worker1   Ready     <none>   1d      v1.13.0        ...,kubernetes.io/hostname=worker1
worker2   Ready     <none>   1d      v1.13.0        ...,kubernetes.io/hostname=worker2
```
In the preceding output, you can see that the worker0 node has a disktype=ssd label.

