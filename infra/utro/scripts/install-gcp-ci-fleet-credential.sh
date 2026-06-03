#!/usr/bin/env bash
# install-gcp-ci-fleet-credential.sh
#
# Idempotently install a GCP service-account JSON key into Jenkins as
# the credential the GCE Jenkins plugin authenticates with.
#
# Credential id:   gcp-ci-fleet-sa-key
# Credential type: Secret file
# Filename inside: ci-fleet-key.json (the plugin reads it from the
#                  attached file; name is just metadata)
#
# When to run:
#   - First-time Jenkins setup after `terraform apply` creates the SA
#   - After `rotate-sa-key.sh --sa ci-fleet` mints a new key
#   - If the credential is manually deleted from the Jenkins UI
#
# The SA itself + its custom-role binding are managed by Terraform
# (../ci-fleet.tf, resources google_service_account.ci_fleet and
# google_project_iam_member.ci_fleet_role). Keys are intentionally
# OUT of Terraform state — minted via gcloud, installed here.
#
# Usage:
#   ./install-gcp-ci-fleet-credential.sh <path-to-key.json>
#
# Or with env-set defaults pointing at the file rotate-sa-key.sh
# leaves in /tmp:
#
#   GCP_SA_KEY_FILE=/tmp/tmp.XXXXXX ./install-gcp-ci-fleet-credential.sh

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://may-chang.folk-saiph.ts.net:8080}"
JENKINS_USER="${JENKINS_USER:-danielbaranowski}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.config/jenkins-admin-token}"
CLI_JAR="${CLI_JAR:-$(cd "$(dirname "$0")" && pwd)/jenkins-cli.jar}"

GCP_SA_KEY_FILE="${1:-${GCP_SA_KEY_FILE:-}}"

[[ -n "$GCP_SA_KEY_FILE" ]] || {
  echo "usage: $0 <path-to-sa-key.json>" >&2
  exit 2
}
[[ -r "$GCP_SA_KEY_FILE" ]] || { echo "missing or unreadable: $GCP_SA_KEY_FILE" >&2; exit 1; }
[[ -f "$TOKEN_FILE"      ]] || { echo "missing $TOKEN_FILE" >&2; exit 1; }
[[ -f "$CLI_JAR"         ]] || { echo "missing $CLI_JAR — fetch from $JENKINS_URL/jnlpJars/jenkins-cli.jar" >&2; exit 1; }
command -v java >/dev/null || { echo "java not on PATH" >&2; exit 1; }

JENKINS_AUTH="${JENKINS_USER}:$(cat "$TOKEN_FILE")"
GCP_SA_KEY_B64=$(base64 < "$GCP_SA_KEY_FILE" | tr -d '\n')

# Inline the base64 into a Groovy script and run via jenkins-cli.
# Single-quoted Groovy string (base64 charset has no `'`).
java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_AUTH" groovy = <<GROOVY
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SecretBytes
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl

def store  = CredentialsProvider.lookupStores(Jenkins.instance).iterator().next()
def domain = Domain.global()
def id     = 'gcp-ci-fleet-sa-key'
def b64    = '${GCP_SA_KEY_B64}'

// Idempotent: remove any existing credential with the same id, then add fresh.
store.getCredentials(domain).findAll { it.id == id }.each {
  store.removeCredentials(domain, it)
  println "Removed existing credential ${id}"
}

store.addCredentials(domain, new FileCredentialsImpl(
  CredentialsScope.GLOBAL,
  id,
  'GCP service-account key for the GCE Jenkins plugin (utro CI fleet)',
  'ci-fleet-key.json',
  SecretBytes.fromBytes(b64.decodeBase64())
))
println "Installed credential ${id}"
GROOVY
