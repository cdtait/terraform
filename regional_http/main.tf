terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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