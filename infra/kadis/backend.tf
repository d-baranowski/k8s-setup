# backend.tf — remote state for the kadis stack.
#
# Same bucket as the utro stack, different key. The state bucket
# (k8s-setup-tfstate-eu-central-1) is created out-of-band via aws-cli, on
# purpose — a stack must not manage its own backend bucket.
#
# use_lockfile is native S3 locking (Terraform >= 1.10), so no DynamoDB table.

terraform {
  backend "s3" {
    bucket       = "k8s-setup-tfstate-eu-central-1"
    key          = "kadis/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
