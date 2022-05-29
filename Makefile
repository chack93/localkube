NAME=gcity_app

.PHONY: help
help:
	@echo "make options\n\
		- init-vm     start 1 master & 2 worker preconfigured multipass vm's\n\
		- list-vm     list multipass vm's\n\
		- sh-master   open shell in master node\n\
		-             \n\
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

.PHONY: x
x:
	echo hello

