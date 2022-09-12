NAME=gcity_app
MASTER_NAME=localkube-master
WORKER_NAME_1=localkube-worker-1
WORKER_NAME_2=localkube-worker-2
ID_RSA_PUB=$(shell cat ~/.ssh/id_rsa.pub)
MASTER_NODE_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${MASTER_NAME}")) | .ipv4[]' -r)
WORKER_NODE_1_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_1}")) | .ipv4[]' -r)
WORKER_NODE_2_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_2}")) | .ipv4[]' -r)
CLOUD_INIT_CONFIG="groups:\n\
	- admingroup: [root,sys]\nssh_authorized_keys:\n\
	- ${ID_RSA_PUB}\nusers:\n\
	- default"
NODE_CONFIG=--cpus 2 --mem 2G --disk 5G --cloud-init tmp-provision-vm-config.yaml 22.04

.PHONY: help
help:
	@echo "make options\n\
		- provision-vm     provision master & 2 worker multipass vm's\n\
		- list-vm          list multipass vm's\n\
		- setup-k8s        setup-vm's & install k8s exec\n\
		- sh-master        open shell in master node\n\
		- sh-worker-1      open shell in worker node 1\n\
		- sh-worker-2      open shell in worker node 2\n\
		-                  \n\
		- help             display this message\n\
		-- vm list --\n\
		${MASTER_NAME}:   ${MASTER_NODE_IP}\n\
		${WORKER_NAME_1}: ${WORKER_NODE_1_IP}\n\
		${WORKER_NAME_2}: ${WORKER_NODE_2_IP}"


.PHONY: destroy-vm
destroy-vm:
	multipass delete ${MASTER_NAME} || true
	multipass delete ${WORKER_NAME_1} || true
	multipass delete ${WORKER_NAME_2} || true
	multipass purge

.PHONY: provision-vm
provision-vm: destroy-vm
	echo ${CLOUD_INIT_CONFIG} > tmp-provision-vm-config.yaml
	multipass launch --name ${MASTER_NAME} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_1} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_2} ${NODE_CONFIG}
	rm -f tmp-provision-vm-config.yaml

.PHONY: list-vm
list-vm:
	multipass list

.PHONY: setup-k8s
setup-k8s: provision-vm
	ssh -o "StrictHostKeyChecking no" ubuntu@${MASTER_NODE_IP} < setup-k8s-exec.sh
	ssh -o "StrictHostKeyChecking no" ubuntu@${WORKER_NODE_1_IP} < setup-k8s-exec.sh
	ssh -o "StrictHostKeyChecking no" ubuntu@${WORKER_NODE_2_IP} < setup-k8s-exec.sh

.PHONY: sh-master
sh-master:
	multipass shell ${MASTER_NAME}

.PHONY: sh-worker-1
sh-worker-1:
	multipass shell ${WORKER_NAME_1}

.PHONY: sh-worker-2
sh-worker-2:
	multipass shell ${WORKER_NAME_2}

.PHONY: x
x:
	echo hello

