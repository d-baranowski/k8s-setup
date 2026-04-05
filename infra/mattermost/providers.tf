# AWS provider configuration
# Set these environment variables before running Terraform:
#   export AWS_ACCESS_KEY_ID="your-access-key"
#   export AWS_SECRET_ACCESS_KEY="your-secret-key"
#   export AWS_REGION="eu-central-1"
# OR create ~/.aws/credentials file
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      application = "mattermost"
      owner       = "k8s-setup/infra/mattermost"
      mattermost  = "true"
      terraform   = "true"
      github      = "k8s-setup"
    }
  }
}

# Google provider configuration
# Use GOOGLE_APPLICATION_CREDENTIALS env var or gcloud application-default login
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  default_labels = {
    application = "mattermost"
    owner       = "k8s-setup-infra-mattermost"
    mattermost  = "true"
    terraform   = "true"
    github      = "k8s-setup"
  }
}
