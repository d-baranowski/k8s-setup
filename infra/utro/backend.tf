# backend.tf — remote state for the utro stack.
#
# Added 2026-07-16 after the original local-only state was lost (no backend
# had ever been configured; terraform.tfstate was a gitignored local file).
# State now lives in S3, versioned + encrypted, with native S3 locking
# (use_lockfile — Terraform >= 1.10, so no DynamoDB table needed). Both repo
# clones share this one state, and `git clean` can no longer wipe it.
#
# The state bucket (k8s-setup-tfstate-eu-central-1) is created out-of-band via
# aws-cli, on purpose — a stack must not manage its own backend bucket.

terraform {
  backend "s3" {
    bucket       = "k8s-setup-tfstate-eu-central-1"
    key          = "utro/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
