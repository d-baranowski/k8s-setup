Terraform example for the `utro` infra

This directory contains a small, self-contained Terraform example showing a recommended project layout and AWS provider configuration.

Quickstart
---------
1. Install Terraform >= 1.3.0.
2. Install aws cli - aws-cli/2.34.0 Python/3.13.12 Darwin/25.3.0 source/arm64
3. Install gcloud cli - gcloud --version                 
   Google Cloud SDK 526.0.1
   bq 2.1.18
   core 2025.06.10
   gcloud-crc32c 1.0.0
 
4. Authenticate with AWS first login in via the web console and then run:
```shell
aws login 
source ./assume-role.sh
```

5. Authenticate with GCP:
```shell
gcloud auth login
gcloud config set project danb-ubuntu-k0s
gcloud auth application-default login
```
Assets: object storage + CDN
----------------------------

`assets.tf` provisions one S3 bucket and one CloudFront distribution per
environment for the assets service (UTR-000266), plus the IAM user it writes
with. `assets-secrets.tf` pushes that user's keys into Google Secret Manager and
renders an ExternalSecret into each environment's cluster directory.

The bucket is never public. CloudFront reaches it through an Origin Access
Control identity and the bucket policy trusts only that one distribution;
`BucketOwnerEnforced` disables ACLs so the public-access block cannot be
undermined by an object ACL later.

DNS is owned by this stack, following the kadis site (kadis repo,
`infra/cloudfront.tf`): the ACM certificate lives in us-east-1, its validation
records and the CDN CNAME are created in Cloudflare, and the CNAME stays
**DNS-only (grey cloud)** — orange-clouding it would terminate TLS at Cloudflare
and defeat CloudFront as the edge.

### Prerequisites

`TerraformAdminUtro` does not ship with ACM or CloudFront permissions — a first
apply fails with `AccessDeniedException` on `acm:RequestCertificate` and
`cloudfront:CreateOriginAccessControl`. The role cannot widen itself, so grant
it once, running as your **base IAM user** rather than the assumed role:

```shell
./bootstrap-assets-role-policy.sh
```

That adds a single inline policy (`terraform-utro-assets`) and leaves every
other policy on the role alone, so it is safe to re-run. Its bucket scoping is
by name — keep it in step with `assets_staging_bucket_name` /
`assets_prod_bucket_name`.

The two asset domains sit in **different Cloudflare zones** (`inspi.cloud` and
`inspiration-particle.com`), so the token must cover both. The one minted by
`../cloudflare/scripts/create-api-token.sh` is account-wide and does; a
single-zone token (like the kadis one) does not.

### Applying

```shell
export CLOUDFLARE_API_TOKEN=...   # see ../cloudflare/scripts/create-api-token.sh
source ./assume-role.sh
terraform apply
```

The first apply blocks while each certificate validates and each distribution
deploys, which is normally a few minutes but can take longer.

Afterwards, wire the service up from the outputs:

```shell
terraform output assets_service_env          # non-secret env for the statefulsets
terraform output assets_distribution_ids     # for cache invalidations
```

Credentials arrive separately, as `STORAGE_ACCESS_KEY` / `STORAGE_SECRET_KEY` in
the generated `*-assets-s3-credentials` secret. The generated ExternalSecret
files still have to be added to the relevant `kustomization.yaml`; Flux does not
pick up files that are not listed.

Set `assets_manage_dns = false` to provision the AWS side without touching DNS.
