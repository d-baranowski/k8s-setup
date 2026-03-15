Terraform example for the `utro` infra

This directory contains a small, self-contained Terraform example showing a recommended project layout and AWS provider configuration.

Quickstart
---------
1. Install Terraform >= 1.3.0.
2. Install aws cli - aws-cli/2.34.0 Python/3.13.12 Darwin/25.3.0 source/arm64
3. Install gcloud cli - gcloud --version                 
   Google Cloud SDK 526.0.1
   bq 2.1.18
   core 2025.06.10
   gcloud-crc32c 1.0.0
 
4. Authenticate with AWS first login in via the web console and then run:
```shell
aws login 
source ./assume-role.sh
```

5. Authenticate with GCP:
```shell
gcloud auth login
gcloud config set project danb-ubuntu-k0s
gcloud auth application-default login
```