# AWS provider configuration
# Set these environment variables before running Terraform:
#   export AWS_ACCESS_KEY_ID="your-access-key"
#   export AWS_SECRET_ACCESS_KEY="your-secret-key"
#   export AWS_REGION="eu-central-1"
# OR create ~/.aws/credentials file (see README)
provider "aws" {
  region = var.aws_region
  # profile removed - will use environment variables or ~/.aws/credentials default profile
  default_tags {
    tags = {
      application = "utro"
      owner       = "k8s-setup/infra/utro"
      utro        = "true"
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

  # Required for the billingbudgets API (and most Cloud Resource Manager
  # endpoints). The google provider does NOT auto-read quota_project_id
  # from the ADC file — without these two lines, API calls go out with
  # no X-Goog-User-Project header and the server bills them against
  # gcloud's own OAuth client project (764086051850), then 403s with a
  # misleading "SERVICE_DISABLED" error.
  billing_project       = var.gcp_project_id
  user_project_override = true

  default_labels = {
    application = "utro"
    owner = "k8s-setup-infra-utro"
    utro = "true"
    terraform = "true"
    github = "k8s-setup"
  }
}

