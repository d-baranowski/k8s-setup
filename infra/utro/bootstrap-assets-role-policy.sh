#!/usr/bin/env bash
#
# Grant TerraformAdminUtro the permissions the assets stack needs
# (S3 asset buckets + CloudFront + ACM + the writer IAM users).
#
# The role cannot grant itself permissions, so this runs as your base IAM user
# (admin), NOT from an already-assumed role. Same shape as the kadis repo's
# bootstrap-terraform-role.sh, which solved this for kadis.inspi.cloud.
#
# This ADDS one inline policy. Other inline and attached policies on the role
# are not touched, so it is safe to re-run.
#
# Run from infra/utro/:
#   ./bootstrap-assets-role-policy.sh
#
# Then:
#   source ./assume-role.sh
#   terraform apply
#
# Overrides:
#   ROLE_NAME       default: TerraformAdminUtro
#   POLICY_NAME     default: terraform-utro-assets
#   STAGING_BUCKET  default: utro-assets-staging
#   PROD_BUCKET     default: utro-assets
#
# Keep the bucket names in step with assets_staging_bucket_name /
# assets_prod_bucket_name in variables.tf — the policy is scoped to them by
# name, so a rename here without a rename there produces an AccessDenied that
# looks like a Terraform bug.

set -euo pipefail

ROLE_NAME="${ROLE_NAME:-TerraformAdminUtro}"
POLICY_NAME="${POLICY_NAME:-terraform-utro-assets}"
STAGING_BUCKET="${STAGING_BUCKET:-utro-assets-staging}"
PROD_BUCKET="${PROD_BUCKET:-utro-assets}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_SRC="${SCRIPT_DIR}/iam-tf-role/assets-access.json"

command -v aws >/dev/null || { echo "ERROR: aws CLI not found in PATH" >&2; exit 1; }

if [[ ! -f "$POLICY_SRC" ]]; then
  echo "ERROR: missing ${POLICY_SRC}" >&2
  exit 1
fi

echo "==> Checking caller identity"
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
echo "    caller:  ${CALLER_ARN}"
echo "    account: ${ACCOUNT_ID}"

# Assuming TerraformAdminUtro and then trying to widen it is the obvious
# mistake here, and the resulting AccessDenied is confusing. Fail early.
if [[ "$CALLER_ARN" == *":assumed-role/${ROLE_NAME}/"* ]]; then
  echo "ERROR: you are running as ${ROLE_NAME} itself, which cannot modify its own" >&2
  echo "       permissions. Open a new shell (or unset AWS_ACCESS_KEY_ID," >&2
  echo "       AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN) and run this as your" >&2
  echo "       base IAM user." >&2
  exit 1
fi

if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "ERROR: role ${ROLE_NAME} does not exist in account ${ACCOUNT_ID}." >&2
  exit 1
fi

POLICY_FILE="$(mktemp)"
trap 'rm -f "$POLICY_FILE"' EXIT

sed -e "s|__STAGING_BUCKET__|${STAGING_BUCKET}|g" \
    -e "s|__PROD_BUCKET__|${PROD_BUCKET}|g" \
    "$POLICY_SRC" > "$POLICY_FILE"

echo "==> Attaching inline policy ${POLICY_NAME} to ${ROLE_NAME}"
echo "    buckets:    ${STAGING_BUCKET}, ${PROD_BUCKET}"
echo "    cloudfront: full (create/update/delete distributions, OAC, policies)"
echo "    acm:        request/describe/delete certificates"
echo "    iam:        users and policies matching utro-assets-*"

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${POLICY_FILE}"

cat <<EOF

==> Done.

  Role:            ${ROLE_NAME}
  Inline policy:   ${POLICY_NAME}

Other policies on this role were not touched.

Now assume the role and apply:

  source ./assume-role.sh
  export CLOUDFLARE_API_TOKEN=...
  terraform apply
EOF
