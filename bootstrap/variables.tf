variable "aws_region" {
  description = "AWS region for state resources"
  type        = string
  default     = "eu-west-2"
}

variable "state_bucket_name" {
  description = "Name of S3 bucket for Terraform state"
  type        = string
  # Must be globally unique - replace with your organization prefix
  default = "id-terraform-state-bucket"
}

variable "dynamodb_table_name" {
  description = "Name of DynamoDB table for state locking"
  type        = string
  default     = "terraform-state-lock"
}