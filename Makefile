SINGLE_K8S_NAME=lk-snc
CONTROL_PLANE_NAME=lk-control
WORKER_NAME_PREFIX=lk-worker-
WORKER_COUNT ?= 3
ARCH ?= $(shell ./get-arch.sh)

SSH_STR=$(shell limactl show-ssh "$(1)" | sed 's/^ssh//')

.PHONY: help
help:
	@echo "make options\n\
		${ARCH}\n\
		- list                    list lima vm's\n\
		--- single node cluster---\n\
		- single-start            start single node lima vm\n\
		- single-stop             stop single node lima vm's\n\
		- single-destroy          destroy single node cluster\n\
		- single-setup            create single node cluster using lima's k8s template\n\
		- single-sh               open shell in single k8s node\n\
		--- k8s cluster---\n\
		- destroy                 destroy all lima vm's related to this k8s env\n\
		- setup-vm                provision control-plane & 3 node lima vm's in background (~10 Min)\n\
		- setup-k8s               install k8s binaries\n\
		- setup                   setup vm & install k8s binaries\n\
		- start                   start all lima vm's\n\
		- stop                    stop all lima vm's\n\
		- sh-control              open shell in control-plane node\n\
		- help                    display this message\n\
---------\n\
 $(shell limactl list | sed 's/$$/\\n/g')\
---------\n\
"

# single node cluster scripts
#

.PHONY: single-stop
single-stop:
	limactl stop ${SINGLE_K8S_NAME} || true

.PHONY: single-start
single-start:
	limactl start ${SINGLE_K8S_NAME} || true

.PHONY: single-destroy
single-destroy:
	kubectl config delete-cluster lk-snc || true
	kubectl config delete-context lk-snc-admin@lk-snc || true
	kubectl config delete-user lk-snc-admin || true
	limactl stop ${SINGLE_K8S_NAME} || true
	limactl delete ${SINGLE_K8S_NAME} || true

.PHONY: single-setup
single-setup: single-destroy
	limactl start --tty=false --set='.arch = "${ARCH}"' --name=${SINGLE_K8S_NAME} ./single-k8s.yaml
	limactl copy ${SINGLE_K8S_NAME}:/tmp/admin.conf ~/.lima/${SINGLE_K8S_NAME}/kube-config.yaml
	sed -i '' 's/kubernetes/lk-snc/g' ~/.lima/${SINGLE_K8S_NAME}/kube-config.yaml
	KUBECONFIG=~/.kube/config:~/.lima/${SINGLE_K8S_NAME}/kube-config.yaml kubectl config view --flatten > gen-sc-admin.conf
	cp gen-sc-admin.conf ~/.kube/config
	rm -f gen-sc-admin.conf

.PHONY: sh-single
sh-single:
	limactl shell ${SINGLE_K8S_NAME}

# cluster scripts
#

.PHONY: destroy
destroy: stop
	kubectl config delete-cluster lk || true
	kubectl config delete-context lk-admin@lk || true
	kubectl config delete-user lk-admin || true
	limactl delete ${CONTROL_PLANE_NAME} || true
	for i in $(shell seq 1 ${WORKER_COUNT}); do limactl delete ${WORKER_NAME_PREFIX}$${i} || true; done

.PHONY: setup-vm
setup-vm:
	kubectl config delete-cluster lk || true
	kubectl config delete-context lk-admin@lk || true
	kubectl config delete-user lk-admin || true
	echo "---VM SETUP IN BACKGROUND---"
	# a fresh start will download all os-images.
	# wait for this one so multiple workers use the local cache instead
	./setup-vm.sh ${CONTROL_PLANE_NAME} --set=".arch=\"${ARCH}\""
	for i in $(shell seq 1 ${WORKER_COUNT}); do ./setup-vm.sh ${WORKER_NAME_PREFIX}$${i} --set=".arch=\"${ARCH}\"" & disown; done

.PHONY: list
list:
	limactl list

.PHONY: start
start:
	limactl start ${CONTROL_PLANE_NAME}
	for i in $(shell seq 1 ${WORKER_COUNT}); do limactl start ${WORKER_NAME_PREFIX}$${i}; done

.PHONY: stop
stop:
	limactl stop ${CONTROL_PLANE_NAME} -f || true
	for i in $(shell seq 1 ${WORKER_COUNT}); do limactl stop ${WORKER_NAME_PREFIX}$${i} -f || true; done

setup-k8s-control: 
	# init control plane & generate join command
	limactl shell ${CONTROL_PLANE_NAME} < setup-k8s-init-control-plane.sh
	limactl copy ${CONTROL_PLANE_NAME}:.kube/config ~/.lima/${CONTROL_PLANE_NAME}/kube-config.yaml
	sed -i '' 's/kubernetes/lk/g' ~/.lima/${CONTROL_PLANE_NAME}/kube-config.yaml
	KUBECONFIG=~/.kube/config:~/.lima/${CONTROL_PLANE_NAME}/kube-config.yaml kubectl config view --flatten > gen-admin.conf
	cp gen-admin.conf ~/.kube/config
	rm -f gen-admin.conf

setup-k8s-worker: 
	limactl shell ${CONTROL_PLANE_NAME} kubeadm token create --print-join-command > gen-join-cmd.sh
	sed -i '' 's/.*/sudo &/' gen-join-cmd.sh
	for i in $(shell seq 1 ${WORKER_COUNT}); do (limactl shell ${WORKER_NAME_PREFIX}$${i} < gen-join-cmd.sh) & disown; done
	rm -f gen-join-cmd.sh

.PHONY: setup-k8s
setup-k8s: setup-k8s-control setup-k8s-worker

wait-for-setup:
	# wait for lima ssh setup
	while [ ! -e ~/.lima/${CONTROL_PLANE_NAME}/ssh.sock  ]; do sleep 1; done || true
	for i in $(shell seq 1 ${WORKER_COUNT}); do (while [ ! -e ~/.lima/${WORKER_NAME_PREFIX}$${i}/ssh.sock  ]; do sleep 1; done || true); done
	# wait again, as ssh.sock file disappears again for a few seconds
	sleep 30
	while [ ! -e ~/.lima/${CONTROL_PLANE_NAME}/ssh.sock  ]; do sleep 1; done || true
	for i in $(shell seq 1 ${WORKER_COUNT}); do (while [ ! -e ~/.lima/${WORKER_NAME_PREFIX}$${i}/ssh.sock  ]; do sleep 1; done || true); done
	# wait for setup-k8s-dependencies.sh to finish
	limactl shell ${CONTROL_PLANE_NAME} sh -c "while [ ! -e /tmp/done ]; do sleep 1; done" || true
	for i in $(shell seq 1 ${WORKER_COUNT}); do (limactl shell ${WORKER_NAME_PREFIX}$${i} sh -c "while [ ! -e /tmp/done  ]; do sleep 1; done" || true); done
	@echo 'done!!!!'

.PHONY: setup
setup: setup-vm wait-for-setup setup-k8s

.PHONY: sh-control
sh-control:
	limactl shell ${CONTROL_PLANE_NAME}

