# ci-fleet-budgets.tf — billing budgets + alert plumbing for the CI fleet.
#
# Two-tier safety net:
#
#   ┌──────────────┐   threshold     ┌────────────────────────┐
#   │  50 PLN      │ ─── 50/90/100% ─→│ email (admin)           │
#   │  monthly     │                  │ Pub/Sub: budget-alerts  │ ──→ (soft-stop:
#   └──────────────┘                  └────────────────────────┘      Cloud Fn
#                                                                       sets
#                                                                       instanceCap=0,
#                                                                       sends SMS —
#                                                                       phase 3)
#
#   ┌──────────────┐   threshold     ┌────────────────────────┐
#   │  500 PLN     │ ─── 100% only  ─→│ email + Pub/Sub        │ ──→ (nuclear:
#   │  monthly     │                  │  topic: budget-nuclear │      Cloud Fn
#   └──────────────┘                  └────────────────────────┘      disables
#                                                                       project
#                                                                       billing —
#                                                                       phase 3)
#
# Phase 3 (Cloud Functions + SMS via Twilio) is *not* in this file yet —
# this only stands up the budgets + Pub/Sub topics + email channels.
# The functions get wired in a follow-up once a Twilio account exists.

locals {
  # The billing account this project pays into. Discovered with
  # `gcloud beta billing projects describe danb-ubuntu-k0s`.
  # Hard-coded here because it's effectively immutable for this project's
  # lifetime (changing it requires re-linking and a separate Owner action).
  ci_fleet_billing_account = "01E9FF-961B9C-A17147"

  # Operator's email — receives budget alert emails at every threshold.
  # Currency is the billing account's native PLN.
  ci_fleet_alert_email = "daniel.m.baranowski@gmail.com"
}

# ─── Pub/Sub topics ─────────────────────────────────────────────────────────

resource "google_pubsub_topic" "budget_alerts" {
  project = local.ci_fleet_project
  name    = "budget-alerts"

  labels = {
    purpose = "ci-fleet-budget-soft-stop"
  }

  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_topic" "budget_nuclear" {
  project = local.ci_fleet_project
  name    = "budget-nuclear"

  labels = {
    purpose = "ci-fleet-budget-nuclear"
  }

  depends_on = [google_project_service.pubsub]
}

# ─── Email notification channel ─────────────────────────────────────────────
# Cloud Monitoring channel that budgets can target. Distinct from the
# raw email field on budgets so we can reuse it across multiple budgets
# and (later) re-target by editing the channel rather than every budget.

resource "google_monitoring_notification_channel" "operator_email" {
  project      = local.ci_fleet_project
  display_name = "Operator email (ci-fleet alerts)"
  type         = "email"
  labels = {
    email_address = local.ci_fleet_alert_email
  }
  description = "Receives budget alert emails for the utro CI fleet — see ci-fleet-budgets.tf"
}

# ─── Budget 1: 50 PLN soft alert ────────────────────────────────────────────
# Pre-existing, originally created by bootstrap-gcp.sh. Imported into
# TF state — see ci-fleet-imports.tf.

resource "google_billing_budget" "ci_fleet_soft" {
  billing_account = local.ci_fleet_billing_account
  display_name    = "utro CI fleet"

  budget_filter {
    projects = ["projects/106477741207"]
  }

  amount {
    specified_amount {
      currency_code = "PLN"
      units         = "50"
    }
  }

  threshold_rules {
    threshold_percent = 0.50
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 0.90
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.00
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.00
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = [google_monitoring_notification_channel.operator_email.id]
    disable_default_iam_recipients   = false
  }
}

# ─── Budget 2: 500 PLN nuclear cutoff ───────────────────────────────────────
# Single hard threshold at 100% of 500 PLN — the kill-switch trigger.
# Forecast-basis rule omitted on purpose: forecasted-spend can swing
# wildly mid-month and we want the nuclear path to fire only on actual
# spend, not projection. The 50 PLN budget already handles forecast
# warnings.

resource "google_billing_budget" "ci_fleet_nuclear" {
  billing_account = local.ci_fleet_billing_account
  display_name    = "utro CI fleet — NUCLEAR"

  budget_filter {
    projects = ["projects/106477741207"]
  }

  amount {
    specified_amount {
      currency_code = "PLN"
      units         = "500"
    }
  }

  threshold_rules {
    threshold_percent = 1.00
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_nuclear.id
    schema_version                   = "1.0"
    monitoring_notification_channels = [google_monitoring_notification_channel.operator_email.id]
    disable_default_iam_recipients   = false
  }
}

# ─── Outputs ────────────────────────────────────────────────────────────────

output "budget_alerts_topic" {
  value       = google_pubsub_topic.budget_alerts.id
  description = "Pub/Sub topic the 50 PLN budget publishes to (soft-stop trigger). Cloud Function subscriber: TODO phase 3."
}

output "budget_nuclear_topic" {
  value       = google_pubsub_topic.budget_nuclear.id
  description = "Pub/Sub topic the 500 PLN budget publishes to (nuclear trigger). Cloud Function subscriber: TODO phase 3."
}
