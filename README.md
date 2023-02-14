# localkube

Collection of setup scripts for a local kubernetes cluster.

## kubeadm setup options

### kubeadm init parameter
1. dns or ip of loadbalancer
--control-plane-endpoint
2. pod network plugin
--pod-network-cidr
3. (optional) explicitly specify container runtime
--cri-socket
4. (optional) explicitly set gateway
--apiserver-advertise-address

```
kubeadm init <args>
```

## Resources

*cloudinit*
https://cloudinit.readthedocs.io/en/latest/topics/examples.html

*kubernetes setup*
https://medium.com/platformer-blog/kubernetes-multi-node-cluster-with-multipass-on-ubuntu-18-04-desktop-f80b92b1c6a7

*k8s doc*
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

cgroup driver?
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/

dns/ip of loadbalancer?
--control-plane-endpoint

pod network add-on?
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network
--pod-network-cidr

