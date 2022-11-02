set -e
set -o pipefail

ARCH=$(arch)
if [ "${ARCH}" = "aarch64" ]; then
  ARCH=arm64
fi

# disable swap
sudo swapoff -a

# load required kernel modules
echo 'overlay' | sudo tee /etc/modules-load.d/containerd.conf
echo 'br_netfilter' | sudo tee -a /etc/modules-load.d/containerd.conf
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
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
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
  kubelet=1.24.0-00 \
  kubeadm=1.24.0-00 \
  kubectl=1.24.0-00
sudo apt-mark hold kubelet kubeadm kubectl

