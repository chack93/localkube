NAME=gcity_app

.PHONY: help
help:
	@echo "make options\n\
		- init-vm     start 1 master & 2 worker preconfigured multipass vm's\n\
		- list-vm     list multipass vm's\n\
		- sh-master   open shell in master node\n\
		- sh-worker-1 open shell in worker node 1\n\
		- sh-worker-2 open shell in worker node 2\n\
		-             \n\
		- help        display this message"

.PHONY: init-vm
init-vm:
	./init-vm.sh

.PHONY: list-vm
list-vm:
	multipass list

.PHONY: sh-master
sh-master:
	multipass shell localkube-master

.PHONY: sh-worker-1
sh-worker-1:
	multipass shell localkube-worker-1

.PHONY: sh-worker-2
sh-worker-2:
	multipass shell localkube-worker-2

.PHONY: x
x:
	echo hello

