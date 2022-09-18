set -e
set -o pipefail

# kubeadm init
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | sudo tee /tmp/kube-init-output

# make kubectl available for non root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

sleep 60 # wait for k8s binaries to function
# apply network plugin
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

