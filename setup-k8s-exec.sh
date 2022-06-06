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
sudo wget "https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-0.20.0-linux-arm64.tar.gz" -O /run/setup-tmp/nerdctl.tar.gz
sudo tar Cxzvf /usr/local/bin /run/setup-tmp/nerdctl.tar.gz

# kubelet kubeadm & kubectl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


# containerd
#sudo mkdir -p /etc/apt/keyrings
#curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg


#######
  #- [ wget, "", -O, /run/setup-tmp ]
  #- [ ls ]


  #- [ echo, "install containerd" ]
  #- [ wget, "", -O, /run/setup-tmp ]
  #- [ ]
  #- [ echo, "install containerd" ]
  #- [ wget, "https://github.com/containerd/containerd/releases/download/v1.6.4/containerd-1.6.4-linux-arm64.tar.gz", -O, /run/setup-tmp/containerd.tar.gz ]
  #- [ tar, Cxzvf, /usr/local/, /run/setup-tmp/containerd.tar.gz ]
  #- [ echo, "install containerd systemd script" ]
  #- [ wget, "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service", -O, /usr/lib/systemd/system/containerd.service ]
  #- [ systemctl, daemon-reload ]
  #- [ systemctl, enable, --now, containerd ]
  #- [ echo, "install cunc" ]
  #- [ wget, "https://github.com/opencontainers/runc/releases/download/v1.1.2/runc.arm64", -O, /usr/local/sbin/runc ]
  #- [ chmod, 755, /usr/local/sbin/runc ]
  #- [ echo, "install cni-plugins" ]
  #- [ wget, "https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-arm64-v1.1.1.tgz", -O, /run/setup-tmp/cni-plugins.tar.gz ]
  #- [ tar, Cxzvf, /opt/cni/bin, /run/setup-tmp/cni-plugins.tar.gz ]
  #- [ echo, "install kubeadm, kubelet & kubectl" ]
  #- [ wget, "https://storage.googleapis.com/kubernetes-release/release/v1.24.1/bin/linux/arm64/kubeadm", -O, /usr/local/bin/kubeadm ]
  #- [ chmod, 755, /usr/local/bin/kubeadm ]
  #- [ wget, "https://storage.googleapis.com/kubernetes-release/release/v1.24.1/bin/linux/arm64/kubelet", -O, /usr/local/bin/kubelet ]
  #- [ chmod, 755, /usr/local/bin/kubelet ]
  #- [ wget, "https://storage.googleapis.com/kubernetes-release/release/v1.24.1/bin/linux/arm64/kubectl", -O, /usr/local/bin/kubectl ]
  #- [ chmod, 755, /usr/local/bin/kubectl ]
  #- [ wget, "https://raw.githubusercontent.com/kubernetes/release/v0.4.0/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service", -O, /etc/systemd/system/kubelet.service ]
  #- [ sed, -i, "s:/usr/bin:/usr/local/bin:g", /etc/systemd/system/kubelet.service ]
  #- [ wget, "https://raw.githubusercontent.com/kubernetes/release/v0.4.0/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf", -O, /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]
  #- [ sed, -i, "s:/usr/bin:/usr/local/bin:g", /etc/systemd/system/kubelet.service.d/10-kubeadm.conf ]
  #- [ systemctl, enable, --now, kubelet ]

