sudo systemctl stop k0scontroller
sudo pkill -f kubelet
sudo systemctl start k0scontroller
sudo k0s kubeconfig admin > ~/.kube/config
chmod 600 ~/.kube/config
sudo setfacl -m u:$(whoami):r /var/lib/k0s/pki/admin.conf
kubectl get nodes 
kubectl get pods --all-namespaces