// random_id is only created (and kept in state) when bucket_name is not supplied.
// It generates an 8-hex-character suffix once and never changes it, unlike the
// uuid() function which produces a new value on every plan and forces bucket replacement.
resource "random_id" "bucket_suffix" {
  count       = var.bucket_name == "" ? 1 : 0
  byte_length = 4 # 4 bytes → 8 hex chars, e.g. "a253e7cf"
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name != "" ? var.bucket_name : format("%s-%s-backups", var.name_prefix, random_id.bucket_suffix[0].hex)

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "AllowBucketObjectsRW"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:PutObjectAcl",
    ]

    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_backup_policy" {
  name        = substr(replace("${var.name_prefix}-s3-backup-policy", "_", "-"), 0, 128)
  description = "Policy granting read/write access to S3 bucket for backups"
  policy      = data.aws_iam_policy_document.s3_access.json
  tags        = var.tags
}

// Optional: create role for IRSA web identity if requested
resource "aws_iam_role" "irsa_role" {
  count = var.create_role && var.oidc_provider_arn != "" && var.sa_name != "" && var.sa_namespace != "" ? 1 : 0

  name = substr(format("%s-s3-backup-role", var.name_prefix), 0, 64)

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            (var.oidc_sub_key) = "system:serviceaccount:${var.sa_namespace}:${var.sa_name}"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  count      = length(aws_iam_role.irsa_role) > 0 ? 1 : 0
  role       = aws_iam_role.irsa_role[0].name
  policy_arn = aws_iam_policy.s3_backup_policy.arn
}

// ---------------------------------------------------------------------------
// Optional: IAM user + access keys
// Use this when pods authenticate via static credentials (e.g. CNPG barman)
// rather than IRSA. Set create_user = true to enable.
// The caller (root module) is responsible for storing the keys wherever needed.
// ---------------------------------------------------------------------------

resource "aws_iam_user" "backup_user" {
  count = var.create_user ? 1 : 0
  name  = substr(format("%s-s3-backup-user", var.name_prefix), 0, 64)
  tags  = var.tags
}

resource "aws_iam_user_policy_attachment" "backup_user_policy" {
  count      = var.create_user ? 1 : 0
  user       = aws_iam_user.backup_user[0].name
  policy_arn = aws_iam_policy.s3_backup_policy.arn
}

resource "aws_iam_access_key" "backup_user_key" {
  count = var.create_user ? 1 : 0
  user  = aws_iam_user.backup_user[0].name
}

// ---------------------------------------------------------------------------
// Optional: lifecycle rules
// The `lifecycle_rules` variable existed long before this resource did, so it
// was silently ignored — passing rules changed nothing. Retention belongs here
// rather than in whatever job writes the backups: S3 expires objects whether or
// not the cluster is healthy, and a job that prunes its own history is one bug
// away from deleting the wrong thing.
//
// Each element accepts: id, prefix, and any of expiration_days,
// noncurrent_version_days, abort_incomplete_multipart_days. Omitted keys mean
// "no such rule clause".
// ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = try(rule.value.status, "Enabled")

      filter {
        prefix = try(rule.value.prefix, "")
      }

      dynamic "expiration" {
        for_each = try(rule.value.expiration_days, null) != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      // Only meaningful with versioning on: this is what stops "deleted"
      // objects from lingering as noncurrent versions you still pay for.
      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_days, null) != null ? [rule.value.noncurrent_version_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      // Failed multipart uploads leave parts behind that are billed but
      // invisible in `aws s3 ls`.
      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_days, null) != null ? [rule.value.abort_incomplete_multipart_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
