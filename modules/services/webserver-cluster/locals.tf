locals {
  # 1. Static constants
  environment = "development"
  project     = "enterprise-app"
  owner       = "cloud-platform-team"

  # 2. Dynamic values (combining things together)
  # This creates: "enterprise-app-development-vpc"
  vpc_name = "${local.project}-${local.environment}-vpc"

  # 3. Standardised Tags for FinOps governance
  common_tags = {
    Environment = local.environment
    Project     = local.project
    Owner       = local.owner
    ManagedBy   = "Terraform"
  }

  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}