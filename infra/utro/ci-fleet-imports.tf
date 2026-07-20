# ci-fleet-imports.tf — Terraform 1.5+ `import` blocks bringing the
# resources that bootstrap-gcp.sh created imperatively into TF state.
#
# WORKFLOW (one-time):
#   1. `terraform plan` — should show "import" lines for every resource
#      below, plus the NEW resources (pub/sub topics, notification channel,
#      500 PLN nuclear budget) as `+ create`. NO `~ update` or `- destroy`
#      should appear for the imported resources — if they do, the TF
#      definitions don't match live state and need adjusting before apply.
#   2. `terraform apply` — performs the imports + creates the new
#      resources in one pass.
#   3. Once apply succeeds clean, these import blocks become no-ops on
#      subsequent runs. They can be deleted after the first successful
#      apply, but harmless to leave in place as documentation of how
#      the state was bootstrapped.
#
# IDs were resolved on 2026-05-15 via:
#   gcloud projects describe danb-ubuntu-k0s --format='value(projectNumber)'
#     → 106477741207
#   gcloud beta billing projects describe danb-ubuntu-k0s
#     → billingAccounts/01E9FF-961B9C-A17147
#   gcloud billing budgets list --billing-account=01E9FF-961B9C-A17147
#     → budgets/b659b4d2-ecbd-452b-b6d4-f28f8e58ea83  "utro CI fleet"
#   gcloud resource-manager tags keys describe danb-ubuntu-k0s/environment
#     → tagKeys/281477463857699
#   gcloud resource-manager tags values describe danb-ubuntu-k0s/environment/Production
#     → tagValues/281478787066106

# ─── API enablements ────────────────────────────────────────────────────────
# ID format: projects/<project>/services/<service>

import {
  to = google_project_service.compute
  id = "danb-ubuntu-k0s/compute.googleapis.com"
}

import {
  to = google_project_service.billingbudgets
  id = "danb-ubuntu-k0s/billingbudgets.googleapis.com"
}

import {
  to = google_project_service.cloudresourcemanager
  id = "danb-ubuntu-k0s/cloudresourcemanager.googleapis.com"
}

import {
  to = google_project_service.iam
  id = "danb-ubuntu-k0s/iam.googleapis.com"
}

import {
  to = google_project_service.pubsub
  id = "danb-ubuntu-k0s/pubsub.googleapis.com"
}

# ─── Environment tag ────────────────────────────────────────────────────────

import {
  to = google_tags_tag_key.environment
  id = "tagKeys/281477463857699"
}

import {
  to = google_tags_tag_value.production
  id = "tagValues/281478787066106"
}

# Tag binding's resource name is URL-encoded — see `gcloud resource-manager
# tags bindings list --parent=//cloudresourcemanager...` output, the `name`
# field. The Terraform provider accepts the percent-encoded form below.
import {
  to = google_tags_tag_binding.project_production
  id = "tagBindings/%2F%2Fcloudresourcemanager.googleapis.com%2Fprojects%2F106477741207/tagValues/281478787066106"
}

# ─── Custom IAM roles ───────────────────────────────────────────────────────

import {
  to = google_project_iam_custom_role.ci_fleet_minimal
  id = "projects/danb-ubuntu-k0s/roles/utroCiFleetMinimal"
}

import {
  to = google_project_iam_custom_role.firewall_updater
  id = "projects/danb-ubuntu-k0s/roles/utroFirewallUpdater"
}

# ─── Service accounts ──────────────────────────────────────────────────────

import {
  to = google_service_account.ci_fleet
  id = "projects/danb-ubuntu-k0s/serviceAccounts/ci-fleet@danb-ubuntu-k0s.iam.gserviceaccount.com"
}

import {
  to = google_service_account.firewall_updater
  id = "projects/danb-ubuntu-k0s/serviceAccounts/utro-firewall-updater@danb-ubuntu-k0s.iam.gserviceaccount.com"
}

# ─── Project IAM bindings (SA → custom role) ───────────────────────────────
# Format: <project> <role> <member>

import {
  to = google_project_iam_member.ci_fleet_role
  id = "danb-ubuntu-k0s projects/danb-ubuntu-k0s/roles/utroCiFleetMinimal serviceAccount:ci-fleet@danb-ubuntu-k0s.iam.gserviceaccount.com"
}

import {
  to = google_project_iam_member.firewall_updater_role
  id = "danb-ubuntu-k0s projects/danb-ubuntu-k0s/roles/utroFirewallUpdater serviceAccount:utro-firewall-updater@danb-ubuntu-k0s.iam.gserviceaccount.com"
}

# ─── Storage bucket + IAM ──────────────────────────────────────────────────

import {
  to = google_storage_bucket.ci_images
  id = "danb-ubuntu-k0s-ci-images"
}

import {
  to = google_storage_bucket_iam_member.ci_fleet_image_read
  id = "b/danb-ubuntu-k0s-ci-images roles/storage.objectViewer serviceAccount:ci-fleet@danb-ubuntu-k0s.iam.gserviceaccount.com"
}

# ─── Existing 100 PLN budget ───────────────────────────────────────────────
# Note: import ID for billing budgets is the full resource path.

import {
  to = google_billing_budget.ci_fleet_soft
  id = "billingAccounts/01E9FF-961B9C-A17147/budgets/b659b4d2-ecbd-452b-b6d4-f28f8e58ea83"
}

# ─── Budget alerting stack (RECOVERED 2026-07-16) ──────────────────────────
# These were originally written as "NEW — no import" (they didn't exist when
# ci-fleet-budgets.tf was first authored). A subsequent `terraform apply`
# created them for real, but that apply's local state was later lost — so
# they now exist in GCP with no state tracking them. Without these import
# blocks, `terraform plan` shows them as `+ create`, which would create
# DUPLICATE budgets/notification-channel and ERROR on the pub/sub topics
# (topic names are unique per project). IDs resolved via:
#   gcloud billing budgets list --billing-account=01E9FF-961B9C-A17147
#   gcloud pubsub topics list / gcloud beta monitoring channels list

import {
  to = google_pubsub_topic.budget_alerts
  id = "projects/danb-ubuntu-k0s/topics/budget-alerts"
}

import {
  to = google_pubsub_topic.budget_nuclear
  id = "projects/danb-ubuntu-k0s/topics/budget-nuclear"
}

import {
  to = google_monitoring_notification_channel.operator_email
  id = "projects/danb-ubuntu-k0s/notificationChannels/4375434328520302034"
}

import {
  to = google_billing_budget.ci_fleet_nuclear
  id = "billingAccounts/01E9FF-961B9C-A17147/budgets/65cee99a-fe84-457b-ac28-6dcdcb5d0ed8"
}
