#!/usr/bin/env bash
# install-cypress-worker-ssh-credential.sh
#
# Idempotently install the GCE Jenkins plugin's SSH bootstrap credential
# into the Jenkins controller's system credentials store.
#
# Credential id:   cypress-worker-ssh-key
# Credential type: SSH Username with private key
# Username:        jenkins
# Private key:     read from /var/lib/jenkins/.ssh/cypress-worker-ssh
#                  on the controller (must be in place beforehand —
#                  scp it from your laptop and `install -o jenkins`).
#
# Re-running this script overwrites the credential in place (same id),
# so it's safe to use for key rotation too.

set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://may-chang.folk-saiph.ts.net:8080}"
JENKINS_USER="${JENKINS_USER:-danielbaranowski}"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.config/jenkins-admin-token}"
CLI_JAR="${CLI_JAR:-$(cd "$(dirname "$0")" && pwd)/jenkins-cli.jar}"

[[ -f "$TOKEN_FILE" ]] || { echo "missing $TOKEN_FILE" >&2; exit 1; }
[[ -f "$CLI_JAR"    ]] || { echo "missing $CLI_JAR — get it from $JENKINS_URL/jnlpJars/jenkins-cli.jar" >&2; exit 1; }

JENKINS_AUTH="${JENKINS_USER}:$(cat "$TOKEN_FILE")"

java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_AUTH" groovy = <<'GROOVY'
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey
import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey.DirectEntryPrivateKeySource
import jenkins.model.Jenkins

def keyPath = '/var/lib/jenkins/.ssh/cypress-worker-ssh'
def keyFile = new File(keyPath)
if (!keyFile.exists()) {
  throw new RuntimeException("private key not found at ${keyPath} on controller — " +
                             "scp it over and chown jenkins:jenkins / chmod 0400 first")
}
def keyText = keyFile.text

def cred = new BasicSSHUserPrivateKey(
  CredentialsScope.GLOBAL,
  'cypress-worker-ssh-key',
  'jenkins',
  new DirectEntryPrivateKeySource(keyText),
  '',
  'GCE Jenkins plugin SSH bootstrap key for cypress workers'
)

def store = Jenkins.instance.getExtensionList(
  'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
)[0].getStore()

def existing = store.getCredentials(Domain.global()).find { it.id == 'cypress-worker-ssh-key' }
if (existing) {
  store.updateCredentials(Domain.global(), existing, cred)
  println "Updated existing credential cypress-worker-ssh-key"
} else {
  store.addCredentials(Domain.global(), cred)
  println "Created credential cypress-worker-ssh-key"
}
GROOVY
