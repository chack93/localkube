CONTROL_PLANE_NAME=lk-control
WORKER_NAME_1=lk-worker1
WORKER_NAME_2=lk-worker2
WORKER_NAME_3=lk-worker3

SSH_STR=$(shell limactl show-ssh "$(1)" | sed 's/^ssh//')

.PHONY: help
help:
	@echo "make options\n\
		- setup-single-k8s        create single node cluster using lima's k8s template\n\
		- destroy-vm              destroy all lima vm's related to this k8s env\n\
		- setup-vm                provision control-plane & 3 node lima vm's in background (~10 Min)\n\
		- setup-k8s               install k8s binaries\n\
		- list-vm                 list lima vm's\n\
		- start-vm                start all lima vm's\n\
		- stop-vm                 stop all lima vm's\n\
		- sh-control              open shell in control-plane node\n\
		- sh-worker-1             open shell in worker 1\n\
		- sh-worker-2             open shell in worker 2\n\
		- sh-worker-3             open shell in worker 3\n\
		- push-config             push k8s_config files to control-plane node\n\
		- pull-config             pull k8s_config files from control-plane node\n\
		- help                    display this message\n\
		"

.PHONY: setup-single-k8s
setup-single-k8s:
	limactl stop k8s || true
	limactl delete k8s || true
	limactl start --tty=false --name=k8s template://k8s

.PHONY: destroy-vm
destroy-vm: stop-vm
	limactl delete ${CONTROL_PLANE_NAME} || true
	limactl delete ${WORKER_NAME_1} || true
	limactl delete ${WORKER_NAME_2} || true
	limactl delete ${WORKER_NAME_3} || true

.PHONY: setup-vm
setup-vm:
	echo "---VM SETUP IN BACKGROUND---"
	./setup-vm.sh ${CONTROL_PLANE_NAME} & disown
	./setup-vm.sh ${WORKER_NAME_1} & disown
	./setup-vm.sh ${WORKER_NAME_2} & disown
	./setup-vm.sh ${WORKER_NAME_3} & disown

.PHONY: list-vm
list-vm:
	limactl list

.PHONY: start-vm
start-vm:
	limactl start ${CONTROL_PLANE_NAME}
	limactl start ${WORKER_NAME_1}
	limactl start ${WORKER_NAME_2}
	limactl start ${WORKER_NAME_3}

.PHONY: stop-vm
stop-vm:
	limactl stop ${CONTROL_PLANE_NAME} || true
	limactl stop ${WORKER_NAME_1} || true
	limactl stop ${WORKER_NAME_2} || true
	limactl stop ${WORKER_NAME_3} || true

.PHONY: setup-k8s
setup-k8s: 
	# init control plane & generate join command
	limactl shell ${CONTROL_PLANE_NAME} < setup-k8s-init-control-plane.sh
	limactl copy ${CONTROL_PLANE_NAME}:.kube/config gen-admin.conf
	limactl shell ${CONTROL_PLANE_NAME} "kubeadm token create --print-join-command" > gen-join-cmd.sh
	sed -i '' 's/.*/sudo &/' gen-join-cmd.sh
	limactl shell ${WORKER_1_NAME} < gen-join-cmd.sh
	limactl shell ${WORKER_2_NAME} < gen-join-cmd.sh
	limactl shell ${WORKER_3_NAME} < gen-join-cmd.sh
	rm -f gen-join-cmd.sh

.PHONY: sh-control
sh-control:
	limactl shell ${CONTROL_PLANE_NAME}

.PHONY: sh-worker-1
sh-worker-1:
	limactl shell ${WORKER_NAME_1}

.PHONY: sh-worker-2
sh-worker-2:
	limactl shell ${WORKER_NAME_2}

.PHONY: sh-worker-3
sh-worker-3:
	limactl shell ${WORKER_NAME_3}

.PHONY: push-config
push-config:
	limactl copy k8s_config/*.yml ${CONTROL_PLANE_NAME}:~/k8s_config/.

.PHONY: pull-config
pull-config:
	limactl copy ${CONTROL_PLANE_NAME}:~/k8s_config/*.yml k8s_config/.

