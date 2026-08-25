# AWS auth: `source ../utro/assume-role.sh` (assumes TerraformAdminUtro, prompts
# for MFA, credentials last ~1h — re-run on ExpiredToken). Same AWS account as
# the utro stack, so the same role covers both.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      application = "kadis"
      owner       = "k8s-setup/infra/kadis"
      kadis       = "true"
      terraform   = "true"
      github      = "k8s-setup"
    }
  }
}

# GCP auth: `gcloud auth application-default login`.
#
# billing_project + user_project_override are required, same as in infra/utro:
# without them the provider sends no X-Goog-User-Project header, the API bills
# calls against gcloud's own OAuth client project and then 403s with a
# misleading "SERVICE_DISABLED".
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region

  billing_project       = var.gcp_project_id
  user_project_override = true

  default_labels = {
    application = "kadis"
    owner       = "k8s-setup-infra-kadis"
    kadis       = "true"
    terraform   = "true"
    github      = "k8s-setup"
  }
}
