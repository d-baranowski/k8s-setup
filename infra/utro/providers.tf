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

# CloudFront will only attach certificates issued in us-east-1, regardless of
# where the buckets live. This alias exists solely to hold those certificates.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

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

# Reads CLOUDFLARE_API_TOKEN from the environment. Only used when
# assets_manage_dns is true; with it false no cloudflare resource is
# instantiated and the token is not needed.
provider "cloudflare" {}

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
    owner       = "k8s-setup-infra-utro"
    utro        = "true"
    terraform   = "true"
    github      = "k8s-setup"
  }
}

# google-beta mirrors the google provider. Firebase / Identity Platform resources
# (google_firebase_project, google_firebase_web_app, google_identity_platform_*) are
# only available in the beta provider. It needs the same billing_project /
# user_project_override as google or Firebase API calls 403 with SERVICE_DISABLED.
provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region

  billing_project       = var.gcp_project_id
  user_project_override = true

  default_labels = {
    application = "utro"
    owner       = "k8s-setup-infra-utro"
    utro        = "true"
    terraform   = "true"
    github      = "k8s-setup"
  }
}

