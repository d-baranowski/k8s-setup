flux reconcile source git flux-system
flux reconcile kustomization atlas-operator
flux reconcile kustomization cert-manager
flux reconcile kustomization external-secrets-operator
flux reconcile kustomization external-secrets-resources
flux reconcile kustomization flux-system
flux reconcile kustomization kubernetes-sigs
flux reconcile kustomization n8n
flux reconcile kustomization nginx-ingress
flux reconcile kustomization openebs
flux reconcile kustomization pg-operator
sleep 3
flux get kustomizations
