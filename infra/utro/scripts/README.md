# infra/utro/scripts

Operational helpers that complement the Terraform stack in `..`. Each
script does one thing Terraform can't or shouldn't.

| Script | What it does | When you run it |
|---|---|---|
| `rotate-sa-key.sh` | Mints a fresh JSON key for a Terraform-managed service account and pushes it to the consumer (Jenkins credential for `ci-fleet`, sops file for `utro-firewall-updater`). SA *bytes* aren't in TF state by design — rotation lives here. | Whenever you want to rotate a key (every 90 days is a reasonable cadence); on suspected compromise. |
| `publish-image.sh` | Builds the cloud-cypress NixOS GCE image (via remote builder), uploads to the TF-managed GCS bucket, registers as a GCE image, bumps the `cloud-cypress` family pointer, prunes old images. | Whenever you change `nixos-workbenches/nixos-servers/hosts/cloud-cypress/` or any module it imports. |
| `install-gcp-ci-fleet-credential.sh` | Idempotently installs a GCP service-account JSON key into Jenkins as the `gcp-ci-fleet-sa-key` Secret-file credential. Auto-invoked by `rotate-sa-key.sh --sa ci-fleet`; can be called standalone for first-time setup or after the credential is manually deleted from the UI. | First-time Jenkins bring-up; recovery if the credential is missing. |
| `install-cypress-worker-ssh-credential.sh` | Idempotently (re-)installs the SSH bootstrap private key the GCE Jenkins plugin uses into Jenkins's credential store (id `cypress-worker-ssh-key`). Reads from `/var/lib/jenkins/.ssh/cypress-worker-ssh` on the controller. | After rotating the cypress-worker SSH keypair (or first-time setup). |
| `jenkins-cli.jar` | Jenkins admin CLI. Gitignored — fetched on demand from `${JENKINS_URL}/jnlpJars/jenkins-cli.jar`. | Used by every `install-*` script and for ad-hoc Groovy. |

## Why these aren't in Terraform

Service-account keys, SSH private keys, and image binaries are credentials
or build artifacts that don't belong in `terraform.tfstate` (state file gets
committed-or-leaked far more easily than these scripts' `--quiet` outputs).
Image lifecycle is also faster-iterating than the IaC change cycle.

## Why they live here and not in `utro/tools/ci/`

Closer to the resources they touch — the Terraform that creates the
SA, the bucket, the IAM bindings is right here in `..`. Less repo
context-switching when working on cloud fleet things.
