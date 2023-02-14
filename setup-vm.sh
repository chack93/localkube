set -e
set -o pipefail

limactl stop $1 || true
limactl delete $1 || true
limactl start --tty=false --name=$1 lima-vm-config.yaml
limactl shell $1 < setup-k8s-dependencies.sh

