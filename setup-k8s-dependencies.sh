set -e
set -o pipefail

ARCH=$(arch)
if [ "${ARCH}" = "aarch64" ]; then
  ARCH=arm64
fi
if [ "${ARCH}" = "x86_64" ]; then
  ARCH=amd64
fi

# disable swap
sudo swapoff -a

# load required kernel modules
echo 'overlay' | sudo tee /etc/modules-load.d/k8s.conf
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/k8s.conf
sudo modprobe overlay
sudo modprobe br_netfilter
# enable ip forwarding
echo '
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
' | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
sudo sysctl --system

# containerd
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo mkdir -p /etc/containerd
sudo systemctl enable containerd
sudo systemctl start containerd
sudo containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# nerdctl
curl -L "https://github.com/containerd/nerdctl/releases/download/v1.0.0/nerdctl-1.0.0-linux-${ARCH}.tar.gz" > /tmp/nerdctl.tar.gz
sudo tar Cxzvvf /usr/local/bin /tmp/nerdctl.tar.gz

# kubernetes
sudo apt-get install -y apt-transport-https curl
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y \
  kubelet=1.26.2-00 \
  kubeadm=1.26.2-00 \
  kubectl=1.26.2-00
sudo apt-mark hold kubelet kubeadm kubectl

# force crictl to use contained instead of dockershim
echo '
runtime-endpoint: "/run/containerd/containerd.sock"
image-endpoint: "/run/containerd/containerd.sock"
timeout: 0
debug: false
pull-image-on-create: false
disable-pull-on-run: false
' | sudo tee /etc/crictl.yaml

# etcdctl
ETCD_VER=v3.4.24
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz
(cd /tmp; tar xf etcd-${ETCD_VER}-linux-${ARCH}.tar.gz)
sudo mv /tmp/etcd-${ETCD_VER}-linux-${ARCH}/etcdctl /usr/local/bin/.

echo done > /tmp/done
