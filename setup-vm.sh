set -e
set -o pipefail

limactl stop $1 -f || true
limactl delete $1 -f || true
sleep $((RANDOM % 30))
limactl start --tty=false --name=$1 lima-vm-config.yaml
sleep $((30+RANDOM % 120))
limactl shell $1 < setup-k8s-dependencies.sh

