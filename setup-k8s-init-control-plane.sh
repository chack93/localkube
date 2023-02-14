set -e
set -o pipefail

IP_ADDR=$(ip addr | grep 'inet 192' | cut -d' ' -f6 | cut -d'/' -f1)

# kubeadm init
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=${IP_ADDR} \
  --kubernetes-version=1.24.0 \
  | sudo tee /tmp/kube-init-output

# make kubectl available for non root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl completion bash > /home/ubuntu/k8s_completion

echo '
source /home/ubuntu/k8s_completion
alias k="kubectl"' >> /home/ubuntu/.profile

sleep 10

# apply network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
#kubectl apply -f calico.yaml
#kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=cidr=10.244.0.0/16

#kubectl create -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
#kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
#kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml

#kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
#kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
#kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
#kubectl taint nodes --all node-role.kubernetes.io/control-plane-
#kubectl taint nodes --all node-role.kubernetes.io/master-


