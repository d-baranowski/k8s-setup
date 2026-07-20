# ci-fleet.tf — utro CI ephemeral cloud-cypress fleet on GCP.
#
# Translates utro/tools/ci/bootstrap-gcp.sh into idempotent Terraform.
# Resources here back the GCE Jenkins plugin running on may-chang —
# provisioning ephemeral on-demand VMs from a NixOS image family for the
# Cypress e2e test shards. (Formerly spot VMs; switched to on-demand
# because the plugin auto-restarts the whole build on preemption with no
# opt-out — see preemptible: false in nixos-workbenches jenkins-casc.nix.)
#
# Source-of-truth ownership boundary:
#   ✓ Terraform owns: APIs, custom IAM roles, service accounts, IAM
#     bindings, storage bucket, environment tag binding.
#   ✗ NOT in Terraform (managed elsewhere):
#       - `cypress-worker-ssh` firewall rule: source range is
#         may-chang's dynamic WAN IP, kept current by the
#         gcp-firewall-updater systemd timer on may-chang
#         (nixos-workbenches/modules/gcp-firewall-updater.nix).
#       - SA *keys*: minted on demand via `gcloud iam service-accounts
#         keys create` and stored in sops on may-chang or as Jenkins
#         credentials. Keeping key bytes out of TF state.
#       - The cloud-cypress GCE image itself: built and published via
#         utro/tools/ci/publish-image.sh (nix-side).
#       - The Jenkins-side configuration (JCasC, SSH credentials):
#         lives in nixos-workbenches and Jenkins's UI/CLI.

locals {
  ci_fleet_project = var.gcp_project_id
  ci_fleet_zone    = "europe-west1-b"
  ci_fleet_region  = "europe-west1"

  # SA emails — used as inputs both to TF resources and to dependent
  # systems (Jenkins credential `gcp-ci-fleet-sa-key` references
  # ci-fleet@..., gcp-firewall-updater.service uses utro-firewall-updater).
  ci_fleet_sa_email          = "ci-fleet@${var.gcp_project_id}.iam.gserviceaccount.com"
  firewall_updater_sa_email  = "utro-firewall-updater@${var.gcp_project_id}.iam.gserviceaccount.com"

  ci_fleet_bucket = "${var.gcp_project_id}-ci-images"
}

# ─── APIs ───────────────────────────────────────────────────────────────────
# Disabling cascades destroys IAM/bucket/etc that depend on these, so we
# keep `disable_on_destroy = false` — a `terraform destroy` here would
# not silently un-enable services on this project.

resource "google_project_service" "compute" {
  project                    = local.ci_fleet_project
  service                    = "compute.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "billingbudgets" {
  project                    = local.ci_fleet_project
  service                    = "billingbudgets.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "cloudresourcemanager" {
  project                    = local.ci_fleet_project
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "iam" {
  project                    = local.ci_fleet_project
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "pubsub" {
  project                    = local.ci_fleet_project
  service                    = "pubsub.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# ─── Environment tag (Resource Manager Tags, not labels) ────────────────────
# Silences the GCP console warning "Project lacks an environment tag" and
# anchors lifecycle policies that depend on classification.

resource "google_tags_tag_key" "environment" {
  parent      = "projects/${local.ci_fleet_project}"
  short_name  = "environment"
  description = "Project environment classification (GCP best practices)"
}

resource "google_tags_tag_value" "production" {
  parent      = google_tags_tag_key.environment.id
  short_name  = "Production"
  description = "Used by utro CI fleet bootstrap"
}

resource "google_tags_tag_binding" "project_production" {
  parent    = "//cloudresourcemanager.googleapis.com/projects/106477741207"
  tag_value = google_tags_tag_value.production.id
}

# ─── Custom IAM role: utroCiFleetMinimal ────────────────────────────────────
# Exactly the perms the GCE Jenkins plugin invokes — see comment block in
# bootstrap-gcp.sh for rationale on what's deliberately absent (no
# osAdminLogin / images.create / firewalls.* / actAs).

resource "google_project_iam_custom_role" "ci_fleet_minimal" {
  project = local.ci_fleet_project
  role_id = "utroCiFleetMinimal"
  title   = "utro CI Fleet (minimal)"
  description = trimspace(<<-EOD
    Minimum perms for utro's GCE Jenkins plugin: create+delete
    VMs from a family image, set metadata/tags/labels at create,
    fetch guest attributes for host-key check. No SSH, no image
    management, no SA attach. SoT: ci-fleet.tf.
  EOD
  )
  stage = "GA"

  permissions = [
    # Project metadata — gcloud calls projects.get on most invocations.
    "resourcemanager.projects.get",

    # Instance lifecycle
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.list",
    "compute.instances.get",
    "compute.instances.use",
    "compute.instances.setMetadata",
    "compute.instances.setLabels",
    "compute.instances.setTags",
    # TESTING perm — flagged by gcloud as not GA. Lets the plugin
    # verify host keys via guest attributes. If GCP demotes this we
    # drop it and accept the "could not verify host key" warning.
    "compute.instances.getGuestAttributes",

    # Disk lifecycle
    "compute.disks.create",
    "compute.disks.delete",
    "compute.disks.get",
    "compute.disks.use",

    # Read-only enumeration — plugin's cloud-config validation queries
    # all of these on every provision attempt.
    "compute.regions.list",
    "compute.regions.get",
    "compute.networks.list",
    "compute.networks.get",
    "compute.networks.use",
    "compute.networks.useExternalIp",
    "compute.subnetworks.list",
    "compute.subnetworks.get",
    "compute.subnetworks.use",
    "compute.subnetworks.useExternalIp",
    "compute.images.list",
    "compute.images.get",
    "compute.images.useReadOnly",
    "compute.machineTypes.get",
    "compute.machineTypes.list",
    "compute.diskTypes.list",
    "compute.diskTypes.get",
    "compute.instanceTemplates.list",
    "compute.instanceTemplates.get",
    "compute.acceleratorTypes.list",
    "compute.acceleratorTypes.get",
    "compute.zones.get",
    "compute.zones.list",
    "compute.zoneOperations.get",
    "compute.zoneOperations.list",
    "compute.globalOperations.get",
    "compute.globalOperations.list",
  ]

  depends_on = [google_project_service.iam]
}

# ─── Custom IAM role: utroFirewallUpdater ───────────────────────────────────
# Used by may-chang's gcp-firewall-updater systemd timer to keep the
# cypress-worker-ssh firewall rule pinned to may-chang's current WAN IP.
# Scoped to firewall get/list/update only — cannot create/delete rules
# or touch any other resource type.

resource "google_project_iam_custom_role" "firewall_updater" {
  project = local.ci_fleet_project
  role_id = "utroFirewallUpdater"
  title   = "utro firewall updater"
  description = trimspace(<<-EOD
    Allows updating source ranges on the cypress-worker-ssh firewall
    rule. Granted only to may-chang's firewall-updater systemd timer.
  EOD
  )
  stage = "GA"

  permissions = [
    "compute.firewalls.get",
    "compute.firewalls.list",
    "compute.firewalls.update",
  ]

  depends_on = [google_project_service.iam]
}

# ─── Service accounts ───────────────────────────────────────────────────────

resource "google_service_account" "ci_fleet" {
  project      = local.ci_fleet_project
  account_id   = "ci-fleet"
  display_name = "Utro CI ephemeral fleet"
  description  = "Used by the GCE Jenkins plugin (on may-chang) to provision Cypress workers"
}

resource "google_service_account" "firewall_updater" {
  project      = local.ci_fleet_project
  account_id   = "utro-firewall-updater"
  display_name = "utro firewall updater"
  description  = "Used by may-chang's gcp-firewall-updater systemd timer"
}

# ─── IAM bindings: each SA gets its narrow custom role ──────────────────────
# Using `_member` (not `_binding` — `_binding` is authoritative and would
# wipe any concurrent bindings on the same role, which is too dangerous
# for a project with multiple TF stacks).

resource "google_project_iam_member" "ci_fleet_role" {
  project = local.ci_fleet_project
  role    = google_project_iam_custom_role.ci_fleet_minimal.id
  member  = "serviceAccount:${google_service_account.ci_fleet.email}"
}

resource "google_project_iam_member" "firewall_updater_role" {
  project = local.ci_fleet_project
  role    = google_project_iam_custom_role.firewall_updater.id
  member  = "serviceAccount:${google_service_account.firewall_updater.email}"
}

# ─── Image bucket ───────────────────────────────────────────────────────────

resource "google_storage_bucket" "ci_images" {
  project                     = local.ci_fleet_project
  name                        = local.ci_fleet_bucket
  location                    = local.ci_fleet_region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # Image tarballs are 1-2 GB; pruning is handled imperatively by
  # publish-image.sh (keeps the 3 newest GCE images, deletes older).
  # No lifecycle rule here — letting the script own retention semantics
  # avoids accidentally deleting an in-flight image upload.
}

# Bucket-level read access for the ci-fleet SA so VM creation can resolve
# the image family. roles/storage.objectViewer is the minimum scope.
resource "google_storage_bucket_iam_member" "ci_fleet_image_read" {
  bucket = google_storage_bucket.ci_images.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.ci_fleet.email}"
}

# ─── Outputs (useful for hand-off to nixos-workbenches / Jenkins) ───────────

output "ci_fleet_sa_email" {
  value       = google_service_account.ci_fleet.email
  description = "Service account the GCE Jenkins plugin authenticates as (credential id: gcp-ci-fleet-sa-key)"
}

output "firewall_updater_sa_email" {
  value       = google_service_account.firewall_updater.email
  description = "Service account may-chang's gcp-firewall-updater systemd timer uses"
}

output "ci_images_bucket" {
  value       = "gs://${google_storage_bucket.ci_images.name}"
  description = "GCS bucket holding cloud-cypress image tarballs (publish-image.sh writes here)"
}
