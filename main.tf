provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_dns_hostnames = true

  tags = local.common_tags
}

# security group to allow the EC2 Instance to receive traffic on port 8080
resource "aws_security_group" "instance" {
  name   = "terraform-example-instance"
  vpc_id = module.vpc.vpc_id # Connects to your existing VPC module

  ingress {
    from_port   = var.ingress_port
    to_port     = var.ingress_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Good practice: Add egress to allow the instance to talk to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # vpc_security_group_ids = [module.vpc.default_security_group_id]
  vpc_security_group_ids = [aws_security_group.instance.id]
  # subnet_id              = module.vpc.private_subnets[0]
  subnet_id = module.vpc.public_subnets[0]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.ingress_port} &
              EOF

  user_data_replace_on_change = true

  # DYNAMIC AUTOMATION FIX: Automatically finds and configures the active Floci container
  provisioner "local-exec" {
    command = <<EOT
      sleep 8
      CONTAINER_ID=$(docker ps --filter "name=floci-ec2-i-" --format "{{.Names}}" | head -n 1)
      echo "Targeting running Floci container: $CONTAINER_ID"
      docker exec $CONTAINER_ID bash -c "apt-get update && apt-get install -y busybox && echo 'Hello, World' > index.html && nohup busybox httpd -f -p 8080 &"
    EOT
  }

  # tags = {
  #   Name = var.instance_name
  # }

  tags = merge(
    local.common_tags,
    { Name = "${local.project}-${var.instance_name}" } # Adds a specific Name tag on top of common tags
  )
}

# ----------------------------

# 1. S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "enterprise-tf-state-9yo-xp" # Must be globally unique
  force_destroy = false                        # Prevent accidental deletion of state

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
  name         = "enterprise-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # This exact string and casing is mandatory for Terraform

  attribute {
    name = "LockID"
    type = "S"
  }
}