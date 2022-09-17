ARCH=$(arch)
if [ ${ARCH} = "aarch64" ]; then
  ARCH=arm64
fi

# disable swap
sudo swapoff -a

# install setup dependencies
sudo apt-get remove docker docker-engine docker.io containerd runc
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

# configure cgroup driver
KUBEADM_VERSION=$(kubeadm version | sed -e 's/.*GitVersion:"//g' -e 's/",.*//g')
echo '
# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: KUBEADM_VERSION
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
' \
  | sed "s/KUBEADM_VERSION/${KUBEADM_VERSION}/g" \
  | sudo tee /run/setup-tmp/kubeadm-config.yaml
sudo kubeadm init --config /run/setup-tmp/kubeadm-config.yaml

# CRI-O
OS="xUbuntu_22.04"
VERSION=$(echo $KUBEADM_VERSION | sed 's/v\([0-9]*.[0-9]*\).*/\1/g')
echo 'deb http://deb.debian.org/debian buster-backports main' | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt-get update -y
sudo apt-get install -y -t buster-backports libseccomp2 || sudo apt-get update -y -t buster-backports libseccomp2

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
sudo mkdir -p /usr/share/keyrings
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
sudo apt-get update -y
sudo apt-get install cri-o cri-o-runc -y

