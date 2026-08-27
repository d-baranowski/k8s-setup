# A private S3 bucket fronted by CloudFront, for public read-only media.
#
# Deliberately not the s3-backup module: that one exists for backup targets a
# job writes and nothing reads over the internet. This bucket is an origin. The
# differences are not cosmetic — ACLs are disabled rather than granted, reads
# are authorised for the CloudFront service principal rather than a user, and
# there is a distribution in front. Forcing both shapes through one module would
# mean a pile of flags that each only make sense for one caller.
#
# Bytes are written by the assets service over the S3 API and read by browsers
# through CloudFront. The bucket itself is never public: public access stays
# blocked and CloudFront reaches it with a signed Origin Access Control identity.
#
# Follows the shape already proven by the kadis site (kadis repo,
# infra/cloudfront.tf): certificate in us-east-1, DNS owned by the same stack
# that owns the distribution, managed cache policy referenced by id.

locals {
  origin_id = "s3"
  subdomain = trimsuffix(var.domain, ".${var.hosted_zone}")

  # AWS managed cache policy "CachingOptimized". Hardcoded so plan does not need
  # cloudfront:ListCachePolicies.
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
  cloudfront_caching_optimized_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

check "subdomain_of_zone" {
  assert {
    condition     = local.subdomain != var.domain && local.subdomain != ""
    error_message = "domain must be a subdomain of hosted_zone (e.g. assets.inspi.cloud under inspi.cloud)."
  }
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Renditions are immutable and reproducible from the original, so versioning
# would only accumulate copies nobody reads. Deletes are driven by the service
# when an asset is removed, and are meant to actually free the storage.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# BucketOwnerEnforced disables ACLs entirely. Access is then decided only by
# the bucket policy and IAM, which is what makes the "no public ACLs" guarantee
# above meaningful rather than merely configured.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Incomplete multipart uploads are billed but do not show up in `aws s3 ls`.
# The assets service uploads whole renditions, so anything left part-uploaded
# is debris from a crash mid-request.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Certificate — must live in us-east-1 for CloudFront to accept it
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name       = var.domain
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = var.manage_dns ? [
    for rec in cloudflare_record.acm : rec.hostname
    ] : [
    for dvo in aws_acm_certificate.this.domain_validation_options : trimsuffix(dvo.resource_record_name, ".")
  ]
}

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

data "cloudflare_zone" "this" {
  count = var.manage_dns ? 1 : 0
  name  = var.hosted_zone
}

resource "cloudflare_record" "acm" {
  for_each = var.manage_dns ? {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name  = trimsuffix(dvo.resource_record_name, ".")
      type  = dvo.resource_record_type
      value = trimsuffix(dvo.resource_record_value, ".")
    }
  } : {}

  zone_id         = data.cloudflare_zone.this[0].id
  name            = each.value.name
  type            = each.value.type
  content         = each.value.value
  ttl             = 60
  proxied         = false
  allow_overwrite = true
  comment         = "ACM DNS validation for ${var.domain}"
}

# DNS-only (grey cloud). Orange-cloud would terminate TLS at Cloudflare and
# defeat CloudFront as the CDN/SSL edge.
resource "cloudflare_record" "cdn" {
  count = var.manage_dns ? 1 : 0

  zone_id = data.cloudflare_zone.this[0].id
  name    = local.subdomain
  type    = "CNAME"
  content = aws_cloudfront_distribution.this.domain_name
  ttl     = 300
  proxied = false
  comment = "${var.name} media via CloudFront"
}

# ---------------------------------------------------------------------------
# CloudFront
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name}-oac"
  description                       = "Signed access from CloudFront to the ${var.name} bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.name}-headers"
  comment = "Cache-Control and CORS for ${var.name}"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = var.cache_control
      override = true
    }
  }

  # The customer app is a Capacitor static export on a different origin, so any
  # future canvas or fetch() use of these images would be blocked without this.
  # Plain <img> tags do not need it. The objects are public through the CDN
  # regardless, so a wildcard grants nothing that was not already readable.
  cors_config {
    access_control_allow_credentials = false
    origin_override                  = true

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.domain
  price_class         = var.price_class
  aliases             = [var.domain]
  http_version        = "http2and3"
  wait_for_deployment = true
  tags                = var.tags

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"

    # Read-only origin. OPTIONS is allowed so the CORS preflight above can be
    # answered; nothing here accepts a write.
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    cache_policy_id            = local.cloudfront_caching_optimized_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # S3 with OAC answers 403 for a key that does not exist, because the caller is
  # not allowed to know the difference. Caching that briefly stops a hot missing
  # key from hammering the origin.
  #
  # The 403 is deliberately not rewritten to 404. CloudFront requires
  # ResponsePagePath and ResponseCode together, and there is no error page to
  # serve from a bucket that holds nothing but image renditions. Granting the
  # CloudFront principal s3:ListBucket would make S3 return a real 404 instead,
  # but it would also make a request to the distribution root return an XML
  # bucket listing, which is a much worse trade than an unhelpful status code.
  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 60
  }
}

# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    # Without this condition any CloudFront distribution in any AWS account
    # could read the bucket.
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  # A bucket policy naming a service principal is not a "public" policy, but
  # the block must exist before the policy or the put races it.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# The assets service writes and deletes renditions. It never creates the bucket
# outside dev, and PutObjectAcl would be rejected under BucketOwnerEnforced, so
# neither is granted.
data "aws_iam_policy_document" "writer" {
  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "AllowObjectReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.this.arn}/*"]
  }
}

resource "aws_iam_policy" "writer" {
  name        = substr("${var.name}-s3-writer-policy", 0, 128)
  description = "Read/write access to the ${var.name} bucket for the assets service"
  policy      = data.aws_iam_policy_document.writer.json
  tags        = var.tags
}

# k3s has no OIDC provider, so IRSA is not available and the service
# authenticates with static keys delivered through External Secrets.
resource "aws_iam_user" "writer" {
  count = var.create_user ? 1 : 0
  name  = substr("${var.name}-s3-writer", 0, 64)
  tags  = var.tags
}

resource "aws_iam_user_policy_attachment" "writer" {
  count      = var.create_user ? 1 : 0
  user       = aws_iam_user.writer[0].name
  policy_arn = aws_iam_policy.writer.arn
}

resource "aws_iam_access_key" "writer" {
  count = var.create_user ? 1 : 0
  user  = aws_iam_user.writer[0].name
}
