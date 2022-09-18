set -e
set -o pipefail

ARCH=$(arch)
if [ ${ARCH} = "aarch64" ]; then
  ARCH=arm64
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
' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system
sudo sysctl -w net.ipv4.ip_forward=1

# install setup dependencies
sudo apt-get remove docker docker-engine docker.io containerd runc || true
sudo apt-get update -y
sudo apt-get install -y \
  wget \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  containerd \
  apt-transport-https

# nerdctl
sudo mkdir -p /run/setup-tmp
sudo wget "https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-0.20.0-linux-${ARCH}.tar.gz" -O /run/setup-tmp/nerdctl.tar.gz
sudo tar Cxzvf /usr/local/bin /run/setup-tmp/nerdctl.tar.gz

# kubelet kubeadm & kubectl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# containerd
sudo apt-get update -y

sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y containerd.io #docker-ce docker-ce-cli docker-compose-plugin
sudo sed -i 's/disabled_plugins/#disabled_plugins/g' /etc/containerd/config.toml
echo '
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
' | sudo tee -a /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

sudo reboot

# cri/cgroups & config ain't working, but keep as reference for now

# CRI-O
OS="xUbuntu_22.04"
KUBEADM_VERSION=$(kubeadm version | sed -e 's/.*GitVersion:"//g' -e 's/",.*//g')
VERSION=$(echo $KUBEADM_VERSION | sed 's/v\([0-9]*.[0-9]*\).*/\1/g')
echo 'deb http://deb.debian.org/debian buster-backports main' | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
sudo apt-get update -y
sudo apt-get install -y -t buster-backports libseccomp2 || sudo apt-get update -y -t buster-backports libseccomp2

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
sudo mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
sudo apt-get update -y
sudo apt-get install cri-o cri-o-runc -y

# configure cgroup driver
sudo mkdir -p /opt/kubeinit
echo '
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: KUBEADM_VERSION
controlPlaneEndpoint: kube-master
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
' \
  | sed "s/KUBEADM_VERSION/${KUBEADM_VERSION}/g" \
  | sudo tee /opt/kubeinit/kubeadm-config.yaml

# kubeadm init
sudo kubeadm init --config /opt/kubeinit/kubeadm-config.yaml

# make kubectl available for non root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# apply network plugin
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
