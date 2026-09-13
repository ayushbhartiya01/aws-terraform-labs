terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }

  required_version = ">= 1.15.8"
}

provider "aws" {
  region = var.aws_region
}

# 1. S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.bucket_name     # Must be globally unique
  force_destroy = false               # Prevent accidental deletion of state

  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so we can roll back state corruption
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicitly block all public access to the state file
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. DynamoDB for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # This exact string and casing is mandatory for Terraform

  attribute {
    name = "LockID"
    type = "S"
  }
}