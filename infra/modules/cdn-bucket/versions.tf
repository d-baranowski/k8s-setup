terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"

      # CloudFront only accepts ACM certificates issued in us-east-1, whatever
      # region the bucket lives in. The caller must pass both providers.
      configuration_aliases = [aws.us_east_1]
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}
