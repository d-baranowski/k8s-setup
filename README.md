# k8s-setup

# Setup git authentication
```
cd ~/.ssh
ssh-keygen -t ed25519 -C "daniel.m.baranowski@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
open https://github.com/settings/keys &
git config --global user.email "daniel.m.baranowski@gmail.com"
git config --global user.name "Daniel Baranowski"
```

# Install k0s
```
curl -sSLf https://get.k0s.sh | sudo sh
k0s version # v1.32.3+k0s.0
```

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

# Alternative file permissions for admin conf
```
sudo chmod 644 /var/lib/k0s/pki/admin.conf
sudo chown $(whoami):$(whoami) /var/lib/k0s/pki/admin.conf
```

# Install Lens 
```
sudo apt update
sudo apt install snapd
sudo snap install kontena-lens --classic
lens
```

# Debugging 
1. Node not ready 
```
sudo systemctl stop k0scontroller
sudo pkill -f kubelet
sudo systemctl start k0scontroller
sudo kubectl get nodes
sudo kubectl get pods --all-namespaces
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

# Install flux cli 
```
curl -s https://fluxcd.io/install.sh | sudo bash -s -- v2.5.1
flux --version  # v2.5.1
```

# Bootstrap flux 
```
open https://github.com/settings/personal-access-tokens &
flux bootstrap github --owner=d-baranowski --repository=k8s-setup --branch=main --path=clusters/home-pc
```
# Service for checking kubeconfig file permissions
```
mkdir -p ~/.local/bin
mkdir -p ~/.config/systemd/user/
```

/home/daniel/.local/bin/fix-kube-perms.sh
```
#!/bin/bash

CONFIG="/var/lib/k0s/pki/admin.conf"
USER="daniel"

# Check ACL for read access
if ! getfacl "$CONFIG" | grep -q "^user:$USER:r"; then
    echo "Fixing ACL for $USER on $CONFIG"
    sudo setfacl -m u:$USER:r "$CONFIG"
fi

# Ensure ~/.kube/config has mode 600
if [ -f "$HOME/.kube/config" ]; then
    current_mode=$(stat -c "%a" "$HOME/.kube/config")
    if [ "$current_mode" != "600" ]; then
        echo "Fixing permissions on ~/.kube/config"
        chmod 600 "$HOME/.kube/config"
    fi
fi
```
Make executable 
```
chmod +x fix-kube-perms.sh
```

~/.config/systemd/user/fix-kube-perms.service
```
[Unit]
Description=Fix kube config and ACL permissions

[Service]
Type=oneshot
ExecStart=/home/daniel/.local/bin/fix-kube-perms.sh
```
~/.config/systemd/user/fix-kube-perms.timer
```
[Unit]
Description=Run fix-kube-perms every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=fix-kube-perms.service

[Install]
WantedBy=timers.target
```
Enable timers
```
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable --now fix-kube-perms.timer
# Check its working
systemctl --user list-timers | grep fix-kube-perms
journalctl --user-unit fix-kube-perms.service
```

# Initialise local vault
```
kubectl exec -n vault -it vault-0 -- vault operator init
```


