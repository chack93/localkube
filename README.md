# localkube

Setup script for a local kubernetes cluster run on lima vm's.

## Lima install instructions

https://github.com/lima-vm/lima

## setup single node cluster

```sh
make single-setup
```

Copy the generated kubeconfig from `~/.lima/k8s/config/kubeconfig.yaml` into ~/.kube/config


## setup local cluster

Install lima to run the vm's.

```sh
brew install lima
```

lima needs a working socket_vmnet to allow guests reaching each other.

```sh
# Install socket_vmnet
brew install socket_vmnet
INST_LOC=$(brew list socket_vmnet |grep bin/socket_vmnet$)
sudo mkdir -p /opt/socket_vmnet/bin
sudo cp ${INST_LOC} /opt/socket_vmnet/bin/socket_vmnet
# Set up the sudoers file for launching socket_vmnet from Lima
limactl sudoers >etc_sudoers.d_lima
sudo install -o root etc_sudoers.d_lima /etc/sudoers.d/lima
rm -f etc_sudoers.d_lima
```

Create 1 control node & 2 workers

```sh
WORKER_COUNT=2 make setup
```

switch to newly generated cluster

```sh
kubectl config use-context lk-admin@lk
```

## change architecture

By default, vm's will run the same cpu architecture as the host.
Use env var ARCH to override this, values: `aarch64` or `x86_64`

```sh
ARCH=aarch64 make setup
```
