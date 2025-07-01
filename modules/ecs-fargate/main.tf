terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # S3 backend configuration - update bucket name after running bootstrap
  backend "s3" {
    # Replace with your actual bucket name from bootstrap output
    bucket         = "id-terraform-state-bucket"
    key            = "ecs-fargate/terraform.tfstate"
    region         = "eu-west-2"
    
    # DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"
    
    # Enable state file encryption
    encrypt = true
    
    # Optional: Use specific KMS key from bootstrap
    # kms_key_id = "arn:aws:kms:eu-west-2:123456789012:key/12345678-1234"
  }
}

# Single AWS provider for the target region
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Region      = var.aws_region
      Terraform   = "true"
    }
  }
}

# Local values for consistent naming
locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.aws_region}"
  
  default_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    Terraform   = "true"
  }
}