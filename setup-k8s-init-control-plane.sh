set -e
set -o pipefail

LIMA_SHARED_INT_IP=$(ip -4 address show lima0 |grep inet | sed 's/.*inet //' | sed 's/\/.*//')
# kubeadm init
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${LIMA_SHARED_INT_IP}

# make kubectl available for non root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

mkdir -p ~/completion/
kubectl completion bash | tee ~/completion/k8s_completion

cd
echo '
source ~/completion/k8s_completion
alias k="kubectl"
' >> ~/.profile

# apply network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
#kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

