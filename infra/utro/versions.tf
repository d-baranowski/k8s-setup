terraform {
  # backend.tf uses native S3 locking (use_lockfile), which landed in 1.10, and
  # the cdn-bucket module uses a check block, which landed in 1.5. The old
  # >= 1.3.0 constraint would have let both fail at parse time on a version
  # Terraform was told was acceptable.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.50.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "6.50.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

