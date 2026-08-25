terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.50.0"
    }
  }
}
