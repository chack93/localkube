NAME=gcity_app
MASTER_NAME=localkube-master
WORKER_NAME_1=localkube-worker-1
WORKER_NAME_2=localkube-worker-2
WORKER_NAME_3=localkube-worker-3
ID_RSA_PUB=$(shell cat ~/.ssh/id_rsa.pub)
MASTER_NODE_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${MASTER_NAME}")) | .ipv4[]' -r)
WORKER_NODE_1_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_1}")) | .ipv4[]' -r)
WORKER_NODE_2_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_2}")) | .ipv4[]' -r)
WORKER_NODE_3_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_3}")) | .ipv4[]' -r)
CLOUD_INIT_CONFIG="\n\
manage_etc_hosts: localhost\n\
groups:\n\
	- admingroup: [root,sys]\n\
ssh_authorized_keys:\n\
	- ${ID_RSA_PUB}\nusers:\n\
	- default\n\
"
NODE_CONFIG=--cpus 2 --mem 2G --disk 5G --cloud-init gen-provision-vm-config.yaml 22.04

ETC_HOSTS_CONFIG="\n\
${MASTER_NODE_IP} ${MASTER_NAME}\n\
${WORKER_NODE_1_IP} ${WORKER_NAME_1}\n\
${WORKER_NODE_2_IP} ${WORKER_NAME_2}\n\
${WORKER_NODE_3_IP} ${WORKER_NAME_3}\n\
"

.PHONY: help
help:
	@echo "make options\n\
		- provision-vm     provision master & 3 worker multipass vm's\n\
		- setup-k8s        setup-vm's & install k8s exec\n\
		- list-vm          list multipass vm's\n\
		- start-vm         start all multipass vm's\n\
		- stop-vm          stop all multipass vm's\n\
		- sh-master        open shell in master node\n\
		- sh-worker-1      open shell in worker node 1\n\
		- sh-worker-2      open shell in worker node 2\n\
		- sh-worker-3      open shell in worker node 3\n\
		-                  \n\
		- help             display this message\n\
		-- vm list --\n\
		${MASTER_NAME}:   ${MASTER_NODE_IP}\n\
		${WORKER_NAME_1}: ${WORKER_NODE_1_IP}\n\
		${WORKER_NAME_2}: ${WORKER_NODE_2_IP}\n\
		${WORKER_NAME_3}: ${WORKER_NODE_3_IP}"


.PHONY: destroy-vm
destroy-vm:
	multipass delete ${MASTER_NAME} || true
	multipass delete ${WORKER_NAME_1} || true
	multipass delete ${WORKER_NAME_2} || true
	multipass delete ${WORKER_NAME_3} || true
	multipass purge

.PHONY: provision-vm
provision-vm: destroy-vm
	echo ${CLOUD_INIT_CONFIG} > gen-provision-vm-config.yaml
	multipass launch --name ${MASTER_NAME} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_1} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_2} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_3} ${NODE_CONFIG}
	rm -f gen-provision-vm-config.yaml

.PHONY: list-vm
list-vm:
	multipass list

.PHONY: start-vm
start-vm:
	multipass start ${MASTER_NAME}
	multipass start ${WORKER_NAME_1}
	multipass start ${WORKER_NAME_2}
	multipass start ${WORKER_NAME_3}


.PHONY: stop-vm
stop-vm:
	multipass stop ${MASTER_NAME}
	multipass stop ${WORKER_NAME_1}
	multipass stop ${WORKER_NAME_2}
	multipass stop ${WORKER_NAME_3}

.PHONY: setup-k8s
setup-k8s: provision-vm
	echo ${ETC_HOSTS_CONFIG} > tmp-hosts
	scp -o StrictHostKeyChecking=no tmp-hosts ubuntu@${MASTER_NODE_IP}:/tmp/tmp-hosts
	ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP} "cat /tmp/tmp-hosts | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_1_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_2_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_3_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	rm -f tmp-hosts
	# setup master node
	ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_1_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_2_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_3_IP} < setup-k8s-dependencies.sh || true
	# wait for kube init script to be executed
	sleep 30
	ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP} < setup-k8s-init-master.sh
	scp -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP}:/tmp/kube-init-output gen-kube-init-output
	scp -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP}:.kube/config admin.conf
	ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_NODE_IP} "kubeadm token create --print-join-command" > gen-join-cmd.sh
	sed -i '' 's/.*/sudo &/' gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_1_IP} < gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_2_IP} < gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_NODE_3_IP} < gen-join-cmd.sh
	rm -f gen-join-cmd.sh

.PHONY: sh-master
sh-master:
	multipass shell ${MASTER_NAME}

.PHONY: sh-worker-1
sh-worker-1:
	multipass shell ${WORKER_NAME_1}

.PHONY: sh-worker-2
sh-worker-2:
	multipass shell ${WORKER_NAME_2}

.PHONY: sh-worker-3
sh-worker-3:
	multipass shell ${WORKER_NAME_3}

