#!/bin/bash

read -p "This will restart your k0s controller and reset kubeconfig. Are you sure? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

sudo systemctl stop k0scontroller
sleep 4
sudo pkill -f kubelet
sleep 4
sudo systemctl start k0scontroller
sleep 4
sudo k0s kubeconfig admin > ~/.kube/config
chmod 600 ~/.kube/config
sudo setfacl -m u:$(whoami):r /var/lib/k0s/pki/admin.conf
kubectl get nodes
kubectl get pods --all-namespaces
