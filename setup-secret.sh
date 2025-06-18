#!/bin/bash

read -p "Enter secret name: " SECRET_NAME
read -s -p "Enter secret value: " SECRET_VALUE
echo
read -p "Enter namespace [default]: " NAMESPACE
NAMESPACE=${NAMESPACE:-default}

# Create secret in Google Secret Manager
gcloud secrets create "$SECRET_NAME" --replication-policy="automatic"
echo -n "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" --data-file=-

# # Create ExternalSecret YAML file
# YAML_PATH="clusters/home-pc/external-secrets-operator/${SECRET_NAME}-secret.yaml"

# mkdir -p "$(dirname "$YAML_PATH")"

# cat > "$YAML_PATH" <<EOF
# apiVersion: external-secrets.io/v1beta1
# kind: ExternalSecret
# metadata:
#    name: ${SECRET_NAME}
#    namespace: ${NAMESPACE}
# spec:
#    refreshInterval: 1h
#    secretStoreRef:
#     name: google-secrets
#     kind: ClusterSecretStore
#    target:
#     name: ${SECRET_NAME}
#     creationPolicy: Owner
#    data:
#      - secretKey: value
#        remoteRef:
#          key: ${SECRET_NAME}
#          version: latest
# EOF
