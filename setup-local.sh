#!/usr/bin/env bash
# setup-local.sh - Run via 'source setup-local.sh' to configure your local terminal for Floci/LocalStack

# 1. Provide mock credentials so Terraform never accidentally hits real AWS
export AWS_ACCESS_KEY_ID="mock-developer-key"
export AWS_SECRET_ACCESS_KEY="mock-developer-secret"
export AWS_DEFAULT_REGION="us-east-1"

# 2. Tell the AWS CLI and Terraform AWS Provider to route ALL service endpoints locally
# This single variable dynamically overrides all endpoints in AWS Provider v5.x+
export AWS_ENDPOINT_URL="http://localhost:4566"

# 3. Handle S3 Path Style configuration for local mock storage
# AWS S3 defaults to virtual-hosted buckets (://amazonaws.com), 
# but local mock containers require path-style routing (localhost:4566/bucket).
export AWS_S3_USE_PATH_STYLE="true"

# 4. Disable metadata checks to prevent local timeouts
export AWS_EC2_METADATA_DISABLED="true"

echo "✅ Environment configured for Floci/LocalStack dev testing!"
