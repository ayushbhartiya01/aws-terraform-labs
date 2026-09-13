variable "bucket_name" {
    description = "The name of the S3 bucket. Must be globally unique."
    type = string
    default = "enterprise-tf-state-9yo-xp"
}

variable "table_name" {
    description = "The name of the dynamo db table. Must be unique in this AWS account"
    type = string
    default = "enterprise-tf-locks"
}

variable "aws_region" {
    description = "The AWS region to deploy the configuration in"
    type = string
    default = "us-east-1"
}