#!/usr/bin/env bash
#
# Assume AWS role and export temporary credentials to environment variables
#
# This script assumes an IAM role and exports the temporary credentials
# as environment variables for use with Terraform or AWS CLI.
#
# Usage:
#   source ./assume-role.sh
#
# Optional environment variables:
#   AWS_PROFILE       - AWS CLI profile to use for assuming role (default: default)
#   ROLE_ARN          - Override the default role ARN
#   ROLE_SESSION_NAME - Override the default session name
#   MFA_SERIAL        - Your MFA device serial (e.g., arn:aws:iam::277265293752:mfa/authy-sub)
#   MFA_TOKEN         - Your 6-digit MFA code (if using MFA)

# Detect if script is being sourced
(return 0 2>/dev/null) && SOURCED=true || SOURCED=false

# Setup error handling that works whether sourced or not
_assume_role_error() {
    local msg="$1"
    echo -e "\033[0;31m[ERROR]\033[0m $msg" >&2
    if [[ "$SOURCED" == true ]]; then
        return 1
    else
        exit 1
    fi
}

_assume_role_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1" >&2
}

_assume_role_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1" >&2
}

# Main function to assume role
_assume_role_main() {
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        _assume_role_error "AWS CLI not found. Please install it first."
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        _assume_role_error "jq not found. Please install it first: brew install jq"
        return 1
    fi

    # Configuration
    local ROLE_ARN="${ROLE_ARN:-arn:aws:iam::277265293752:role/TerraformAdminUtro}"
    local ROLE_SESSION_NAME="${ROLE_SESSION_NAME:-cli-temp}"
    local AWS_PROFILE="${AWS_PROFILE:-default}"
    local MFA_SERIAL="${MFA_SERIAL:-arn:aws:iam::277265293752:mfa/authy-sub}"

    _assume_role_info "Assuming role: $ROLE_ARN" >&2
    _assume_role_info "Session name: $ROLE_SESSION_NAME" >&2
    _assume_role_info "Profile: $AWS_PROFILE" >&2

    # Build the assume-role command
    local ASSUME_ROLE_CMD="aws sts assume-role --role-arn ${ROLE_ARN} --role-session-name ${ROLE_SESSION_NAME} --profile ${AWS_PROFILE}"

    # Check if MFA is required (try without first, then with if it fails)
    _assume_role_info "Attempting to assume role..." >&2
    local RESPONSE
    RESPONSE=$(eval "$ASSUME_ROLE_CMD" 2>&1 || true)

    if echo "$RESPONSE" | grep -q "MFA authentication required"; then
        _assume_role_warn "MFA authentication required" >&2

        # Prompt for MFA token if not provided
        local MFA_TOKEN="${MFA_TOKEN:-}"
        if [[ -z "$MFA_TOKEN" ]]; then
            read -p "Enter your 6-digit MFA code: " -r MFA_TOKEN
        fi

        if [[ ! "$MFA_TOKEN" =~ ^[0-9]{6}$ ]]; then
            _assume_role_error "Invalid MFA token format. Must be 6 digits."
            return 1
        fi

        ASSUME_ROLE_CMD="${ASSUME_ROLE_CMD} --serial-number ${MFA_SERIAL} --token-code ${MFA_TOKEN}"
        _assume_role_info "Retrying with MFA..." >&2
        RESPONSE=$(eval "$ASSUME_ROLE_CMD" 2>&1 || true)
    fi

    # Check if the assume-role command succeeded
    if ! echo "$RESPONSE" | jq . >/dev/null 2>&1; then
        _assume_role_error "Failed to assume role"
        _assume_role_error "Response: $RESPONSE"
        return 1
    fi

    # Extract credentials from the response
    local ACCESS_KEY
    local SECRET_KEY
    local SESSION_TOKEN
    local EXPIRATION

    ACCESS_KEY=$(echo "$RESPONSE" | jq -r '.Credentials.AccessKeyId')
    SECRET_KEY=$(echo "$RESPONSE" | jq -r '.Credentials.SecretAccessKey')
    SESSION_TOKEN=$(echo "$RESPONSE" | jq -r '.Credentials.SessionToken')
    EXPIRATION=$(echo "$RESPONSE" | jq -r '.Credentials.Expiration')

    if [[ -z "$ACCESS_KEY" ]] || [[ -z "$SECRET_KEY" ]] || [[ -z "$SESSION_TOKEN" ]]; then
        _assume_role_error "Failed to extract credentials from response"
        return 1
    fi

    # Get the region from AWS config
    local REGION
    REGION=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null || echo "eu-central-1")

    # Export the environment variables directly
    export AWS_ACCESS_KEY_ID="${ACCESS_KEY}"
    export AWS_SECRET_ACCESS_KEY="${SECRET_KEY}"
    export AWS_SESSION_TOKEN="${SESSION_TOKEN}"
    export AWS_REGION="${REGION}"
    export AWS_DEFAULT_REGION="${REGION}"

    _assume_role_info "✓ Credentials obtained successfully!" >&2
    _assume_role_info "Credentials expire at: $EXPIRATION" >&2
    _assume_role_info "" >&2
    _assume_role_info "Environment variables set:" >&2
    _assume_role_info "  AWS_ACCESS_KEY_ID=${ACCESS_KEY:0:10}..." >&2
    _assume_role_info "  AWS_REGION=${REGION}" >&2
    _assume_role_info "" >&2
    _assume_role_info "You can now run:" >&2
    echo -e "\033[0;34m  terraform plan\033[0m" >&2
    echo -e "\033[0;34m  terraform apply\033[0m" >&2
    _assume_role_info "" >&2

    return 0
}

# Run the main function
_assume_role_main
