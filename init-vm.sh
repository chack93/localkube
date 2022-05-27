multipass delete localkube-master
multipass delete localkube-worker-1
multipass delete localkube-worker-2
multipass purge

multipass launch --name localkube-master --cpus 2 --mem 2G --disk 5G --cloud-init init-vm-cloud-config.yaml
multipass launch --name localkube-worker-1 --cpus 2 --mem 2G --disk 5G --cloud-init init-vm-cloud-config.yaml
multipass launch --name localkube-worker-2 --cpus 2 --mem 2G --disk 5G --cloud-init init-vm-cloud-config.yaml

