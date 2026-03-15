resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name != "" ? var.bucket_name : format("%s-%s-backups", var.name_prefix, substr(uuid(), 0, 8))

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
