# k8s-setup
# Install k0s
`curl -sSLf https://get.k0s.sh | sudo sh`
 k0s version # v1.32.3+k0s.0

# Initialise cluster 
```
sudo k0s install controller --single
sudo k0s start
sudo k0s status
```

# Set up kubectl
```
sudo k0s kubeconfig admin > ~/.kube/config
chmod 600 ~/.kube/config
sudo setfacl -m u:$(whoami):r /var/lib/k0s/pki/admin.conf
kubectl get pods
```

# Ensure node is not tainted and will accept pods
```
kubectl get nodes -o json | jq '.items[].spec.taints'
```

# Install helm
```
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version # v3.17.2
```

# Add Flux Helm Repository
```
helm repo add fluxcd https://fluxcd-community.github.io/helm-charts
helm repo update
kubectl create ns flux-system
helm upgrade -i flux fluxcd/flux2 \
  --namespace flux-system \
  --set installCRDs=true
kubectl get pods -n flux-system
```

# Install flux cli 
curl -s https://fluxcd.io/install.sh | sudo bash -s -- v2.5.1
flux --version  # v2.5.1


# Bootstrap flux 
```
flux bootstrap github \
  --owner=d-baranowski \
  --repository=k8s-setup \
  --branch=main \
  --path=clusters/home-pc \
  --url=ssh://git@github.com/d-baranowski/k8s-setup.git
```
