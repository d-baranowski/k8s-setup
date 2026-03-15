#!/usr/bin/env bash
#
# Export AWS credentials from CLI session to environment variables
#
# This script extracts credentials from your AWS CLI session and
# outputs export statements that you can eval or source.
#
# Usage:
#   source ./export-aws-creds.sh
#
# OR:
#   eval $(./export-aws-creds.sh)
#
# OR to use a specific profile:
#   AWS_PROFILE=my-profile source ./export-aws-creds.sh

set -euo pipefail

# Colors for output (only when not being sourced/eval'd)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it first."
    exit 1
fi

# Get credentials from AWS CLI configuration
# This works if you're logged in via web console or have a session
PROFILE="${AWS_PROFILE:-default}"

log_info "Extracting credentials from AWS CLI (profile: $PROFILE)..." >&2

# Try to get caller identity to verify credentials work
if ! aws sts get-caller-identity --profile "$PROFILE" >/dev/null 2>&1; then
    log_error "Failed to authenticate with AWS CLI profile '$PROFILE'" >&2
    log_error "Make sure you're logged in: aws login" >&2
    exit 1
fi

# Check if credentials file exists and has the profile
CREDS_FILE="${HOME}/.aws/credentials"
if [[ ! -f "$CREDS_FILE" ]]; then
    log_error "Credentials file not found at $CREDS_FILE" >&2
    log_error "Please run: aws login" >&2
    exit 1
fi

# Extract credentials from credentials file
ACCESS_KEY=$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null || echo "")
SECRET_KEY=$(aws configure get aws_secret_access_key --profile "$PROFILE" 2>/dev/null || echo "")
SESSION_TOKEN=$(aws configure get aws_session_token --profile "$PROFILE" 2>/dev/null || echo "")
REGION=$(aws configure get region --profile "$PROFILE" 2>/dev/null || echo "eu-central-1")

if [[ -z "$ACCESS_KEY" ]] || [[ -z "$SECRET_KEY" ]]; then
    log_error "Could not extract credentials from profile '$PROFILE'" >&2
    exit 1
fi

# Output the export statements
echo "export AWS_ACCESS_KEY_ID=\"${ACCESS_KEY}\""
echo "export AWS_SECRET_ACCESS_KEY=\"${SECRET_KEY}\""
if [[ -n "$SESSION_TOKEN" ]]; then
    echo "export AWS_SESSION_TOKEN=\"${SESSION_TOKEN}\""
fi
echo "export AWS_REGION=\"${REGION}\""
echo "export AWS_DEFAULT_REGION=\"${REGION}\""

log_info "✓ Credentials exported successfully!" >&2
log_info "You can now run: terraform plan" >&2

