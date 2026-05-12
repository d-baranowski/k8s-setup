provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      application = "observability"
      owner       = "k8s-setup/infra/observability"
      observability = "true"
      terraform   = "true"
      github      = "k8s-setup"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  default_labels = {
    application   = "observability"
    owner         = "k8s-setup-infra-observability"
    observability = "true"
    terraform     = "true"
    github        = "k8s-setup"
  }
}
