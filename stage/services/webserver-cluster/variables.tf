variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket used for the database's remote state storage"
  type        = string
  default = "enterprise-tf-state-9yo-xp"
}

variable "db_remote_state_key" {
  description = "The name of the key in the S3 bucket used for the database's remote state storage"
  type        = string
  default = "stage/data-stores/mysql/terraform.tfstate"
}


variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "learn-terraform"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t2.micro"
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

variable "alb_name" {
  description = "The name of the ALB"
  type        = string
  default     = "terraform-asg-example"
}

variable "instance_security_group_name" {
  description = "The name of the security group for the EC2 Instances"
  type        = string
  default     = "terraform-example-instance"
}

variable "alb_security_group_name" {
  description = "The name of the security group for the ALB"
  type        = string
  default     = "terraform-example-alb"
}

variable "aws_region" {
  description = "The AWS region to deploy the configuration in"
  type        = string
  default     = "us-east-1"  
}