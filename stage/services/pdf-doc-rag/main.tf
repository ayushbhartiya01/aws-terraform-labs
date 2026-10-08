variable "image_tag" {
  type        = string
  description = "The specific ECR container image tag to deploy (e.g., Git commit SHA)"
  default     = "latest"
}

variable "groq_api_key" {
  type        = string
  sensitive   = true # Tells Terraform to mask this value in all console logs
  description = "The secret API key for Groq inference runtime executions"
}

variable "groq_model" {
  type        = string
  default     = "llama-3.3-70b-versatile"
  description = "The deployment LLM signature used by the RAG pipeline"
}

# 1. Define the AWS Cloud Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # We will deploy to N. Virginia to keep it simple
}


# 2. Create an Amazon ECS Cluster (a logical grouping of containers)
resource "aws_ecs_cluster" "rag_cluster" {
  name = "pdf-rag-production-cluster"
}


# 3. Create the IAM Execution Role so ECS has permission to create logs
resource "aws_iam_role" "ecs_execution_role" {
  name = "pdf-rag-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# 4. Define the Task Definition (The blueprint explaining how to run your container)
resource "aws_ecs_task_definition" "rag_task" {
  family                   = "pdf-doc-rag-task"
  network_mode             = "awsvpc"       # Required for Fargate
  requires_compatibilities = ["FARGATE"]    # Run serverless without managing EC2 VMs
  cpu                      = "512"          # Lowest affordable setting (0.25 vCPU)
  memory                   = "1024"          # Lowest affordable setting (512 MB)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "rag-app-container"
    # Point directly to the public image you just generated in your previous step!
    image     = "public.ecr.aws/s2r2u0a9/pdf-doc-rag-prod:${var.image_tag}"
    essential = true

    # Inject temporary mock strings if your pipeline checks for presence on startup
    environment = [
      { name = "GROQ_API_KEY", value = var.groq_api_key },
      { name = "GROQ_MODEL", value = var.groq_model },
      { name = "LOCAL_EMBEDDING_MODEL", value = "sentence-transformers/all-MiniLM-L6-v2" }
    ]

    # Force the container to run an infinite sleep loop to prevent it from exiting
    # command   = ["sleep", "infinity"]
    
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]

    # Inject the logging configurations natively
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/pdf-doc-rag"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }

  }])
}


# 5. Automatically look up your account's default network configurations
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 6. Create a Security Group (Firewall) to allow traffic into port 8000
resource "aws_security_group" "rag_api_sg" {
  name        = "pdf-rag-api-security-group"
  description = "Allow inbound traffic on app port 8000"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows access from the internet for testing
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows container to talk out to ECR and download packages
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Create the ECS Service (The Manager that spins up tasks)
resource "aws_ecs_service" "rag_service" {
  name            = "pdf-doc-rag-service"
  cluster         = aws_ecs_cluster.rag_cluster.id
  task_definition = aws_ecs_task_definition.rag_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Run exactly one copy of our container

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.rag_api_sg.id]
    assign_public_ip = true # Required for default public subnets to download ECR images
  }
}


# 1. Create a dedicated CloudWatch Log Group for your RAG application
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/pdf-doc-rag"
  retention_in_days = 7
}
