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
    from_port   = var.server_port
    to_port     = var.server_port
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

# 9. ALB Security Group
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_launch_template" "example" {
  name_prefix   = "example-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Security groups are passed inside the network_interfaces block
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
  }

  # User data must be base64 encoded in a launch template
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  )

  # Recommended: Prevent resource destruction issues when updating Auto Scaling Groups
  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "bootstrap_floci_instances" {
  # This ensures the provisioner runs ONLY after the ASG has fully finished creating the containers
  depends_on = [aws_autoscaling_group.example]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting 5 seconds for Floci containers to fully settle..."
      sleep 5
      
      # Find all active container IDs matching your Floci EC2 instances
      CONTAINERS=$(docker ps --filter "name=floci-ec2-i-" --format "{{.ID}}")
      
      for CONTAINER in $CONTAINERS; do
        echo "Bootstrapping web server inside Floci container: $CONTAINER"
        
        # 1. Install busybox and prepare files synchronously
        docker exec $CONTAINER bash -c "apt-get update && apt-get install -y busybox && mkdir -p /var/www && echo 'Hello, World' > /var/www/index.html"
        
        # 2. Start the webserver DETACHED (-d) so Docker keeps the background process alive
        docker exec -d $CONTAINER busybox httpd -f -p 8080 -h /var/www
      done
    EOT
  }
}


# 2. Updated Auto Scaling Group using Launch Template syntax
resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.asg.arn]
  health_check_type   = "ELB"

  min_size = 2
  max_size = 10

  # Point to the launch template instead of launch_configuration
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }

  # Ensures the ASG rolls over instances seamlessly when the template updates
  lifecycle {
    create_before_destroy = true
  }
}

# 3. Networking Data Sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 5. Application Load Balancer
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

# 6. ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# 7. ALB Listener Rule
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# 8. ALB Target Group
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
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