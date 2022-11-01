NAME=gcity_app
CONTROL_PLANE_NAME=lk-control
WORKER_NAME_1=lk-worker1
WORKER_NAME_2=lk-worker2
WORKER_NAME_3=lk-worker3
ID_RSA_PUB=$(shell cat ~/.ssh/id_rsa.pub)
CONTROL_PLANE_NODE_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${CONTROL_PLANE_NAME}")) | .ipv4[]' -r)
WORKER_1_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_1}")) | .ipv4[]' -r)
WORKER_2_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_2}")) | .ipv4[]' -r)
WORKER_3_IP=$(shell multipass list --format json | jq '.list[] | select(.name|test("${WORKER_NAME_3}")) | .ipv4[]' -r)
CLOUD_INIT_CONFIG="\n\
manage_etc_hosts: localhost\n\
groups:\n\
	- admingroup: [root,sys]\n\
ssh_authorized_keys:\n\
	- ${ID_RSA_PUB}\nusers:\n\
	- default\n\
"
NODE_CONFIG=--cpus 2 --mem 2G --disk 5G --cloud-init gen-provision-vm-config.yaml 20.04

ETC_HOSTS_CONFIG="\n\
${CONTROL_PLANE_NODE_IP}	${CONTROL_PLANE_NAME}\n\
${WORKER_1_IP}	${WORKER_NAME_1}\n\
${WORKER_2_IP}	${WORKER_NAME_2}\n\
${WORKER_3_IP}	${WORKER_NAME_3}\n\
"

.PHONY: help
help:
	@echo "make options\n\
		- destroy-vm              destroy all multipass vm's related to this k8s env\n\
		- provision-vm            provision control-plane & 3 node multipass vm's\n\
		- setup-k8s               setup-vm's & install k8s exec\n\
		- list-vm                 list multipass vm's\n\
		- start-vm                start all multipass vm's\n\
		- stop-vm                 stop all multipass vm's\n\
		- sh-control-plane        open shell in control-plane node\n\
		- sh-worker-1             open shell in worker 1\n\
		- sh-worker-2             open shell in worker 2\n\
		- sh-worker-3             open shell in worker 3\n\
		- help                    display this message\n\
		\n\
		-- vm list --\n\
		${CONTROL_PLANE_NAME}:    ${CONTROL_PLANE_NODE_IP}\n\
		${WORKER_NAME_1}:    ${WORKER_1_IP}\n\
		${WORKER_NAME_2}:    ${WORKER_2_IP}\n\
		${WORKER_NAME_3}:    ${WORKER_3_IP}"


.PHONY: destroy-vm
destroy-vm:
	multipass delete ${CONTROL_PLANE_NAME} || true
	multipass delete ${WORKER_NAME_1} || true
	multipass delete ${WORKER_NAME_2} || true
	multipass delete ${WORKER_NAME_3} || true
	multipass purge

.PHONY: _provision-vm-1st-step
_provision-vm-1st-step:
	echo ${CLOUD_INIT_CONFIG} > gen-provision-vm-config.yaml
	multipass launch --name ${CONTROL_PLANE_NAME} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_1} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_2} ${NODE_CONFIG}
	multipass launch --name ${WORKER_NAME_3} ${NODE_CONFIG}
	rm -f gen-provision-vm-config.yaml

.PHONY: provision-vm
provision-vm: destroy-vm _provision-vm-1st-step
	# setup hostname config
	ssh -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP} "sudo hostnamectl set-hostname ${CONTROL_PLANE_NAME}"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_1_IP} "sudo hostnamectl set-hostname ${WORKER_NAME_1}"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_2_IP} "sudo hostnamectl set-hostname ${WORKER_NAME_2}"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_3_IP} "sudo hostnamectl set-hostname ${WORKER_NAME_3}"
	# setup /etc/hosts config
	echo ${ETC_HOSTS_CONFIG} > tmp-hosts
	scp -o StrictHostKeyChecking=no tmp-hosts ubuntu@${CONTROL_PLANE_NODE_IP}:/tmp/tmp-hosts
	ssh -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP} "cat /tmp/tmp-hosts | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_1_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_2_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_3_IP} "echo ${ETC_HOSTS_CONFIG} | sudo tee -a /etc/hosts"
	rm -f tmp-hosts

.PHONY: list-vm
list-vm:
	multipass list

.PHONY: start-vm
start-vm:
	multipass start ${CONTROL_PLANE_NAME}
	multipass start ${WORKER_NAME_1}
	multipass start ${WORKER_NAME_2}
	multipass start ${WORKER_NAME_3}


.PHONY: stop-vm
stop-vm:
	multipass stop ${CONTROL_PLANE_NAME} || true
	multipass stop ${WORKER_NAME_1} || true
	multipass stop ${WORKER_NAME_2} || true
	multipass stop ${WORKER_NAME_3} || true

.PHONY: setup-k8s
setup-k8s: provision-vm
	# setup control-plane node
	ssh -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_1_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_2_IP} < setup-k8s-dependencies.sh || true
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_3_IP} < setup-k8s-dependencies.sh || true
	# wait for kube init script to be executed
	sleep 30
	ssh -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP} < setup-k8s-init-control-plane.sh
	scp -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP}:/tmp/kube-init-output gen-kube-init-output
	scp -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP}:.kube/config gen-admin.conf
	ssh -o StrictHostKeyChecking=no ubuntu@${CONTROL_PLANE_NODE_IP} "kubeadm token create --print-join-command" > gen-join-cmd.sh
	sed -i '' 's/.*/sudo &/' gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_1_IP} < gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_2_IP} < gen-join-cmd.sh
	ssh -o StrictHostKeyChecking=no ubuntu@${WORKER_3_IP} < gen-join-cmd.sh
	rm -f gen-join-cmd.sh

.PHONY: sh-control-plane
sh-control-plane:
	multipass shell ${CONTROL_PLANE_NAME}

.PHONY: sh-worker-1
sh-worker-1:
	multipass shell ${WORKER_NAME_1}

.PHONY: sh-worker-2
sh-worker-2:
	multipass shell ${WORKER_NAME_2}

.PHONY: sh-worker-3
sh-worker-3:
	multipass shell ${WORKER_NAME_3}

