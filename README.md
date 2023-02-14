# localkube

Setup script for a local kubernetes cluster run on lima vm's.

## Lima install instructions

https://github.com/lima-vm/lima

## setup single node cluster

```sh
make setup-single-k8s
```

Copy the generated kubeconfig from `~/.lima/k8s/config/kubeconfig.yaml` into ~/.kube/config


## setup local cluster

```sh
make setup-vm
```

wait for completion (~10 Minutes)

```sh
make setup-k8s
```

