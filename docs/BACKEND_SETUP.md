# Backend Configuration Guide

This guide explains how to set up S3 backend for Terraform state management.

## Overview

The repository uses a **two-step process**:
1. **Bootstrap**: Creates S3 bucket and DynamoDB table for state storage
2. **Configure Backend**: Updates ECS module to use the created resources

## Step 1: Run Bootstrap (One-Time Setup)

### 1.1 Create Bootstrap Configuration
Copy the example and customize with your values:
```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `bootstrap/terraform.tfvars` with your specific values:
```hcl
aws_region = "eu-west-2"  # Your preferred region
state_bucket_name = "your-org-terraform-state-bucket"  # Must be globally unique
dynamodb_table_name = "terraform-state-lock"
```

**Important**: The `state_bucket_name` must be globally unique across all AWS accounts. Replace `your-org` with your organization name or a unique identifier.

### 1.2 Run Bootstrap
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

### 1.3 Note the Outputs
After applying, note these values:
```bash
terraform output state_bucket_name
terraform output dynamodb_table_name
terraform output kms_key_arn
```

## Step 2: Configure Backend in ECS Module

The ECS module is already configured to use the bootstrap resources:

```hcl
# modules/ecs-fargate/main.tf
terraform {
  backend "s3" {
    bucket         = "your-org-terraform-state-bucket"  # Match your bootstrap bucket name
    key            = "ecs-fargate/terraform.tfstate"
    region         = "eu-west-2"                        # Match your bootstrap region
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Important**: After running bootstrap, update the `bucket` and `region` values in `modules/ecs-fargate/main.tf` to match the values you used in your `bootstrap/terraform.tfvars` file.

### 2.1 Initialize with Backend
```bash
cd modules/ecs-fargate
terraform init
```

You'll see a message about migrating state to S3.

### 2.2 Verify Backend Configuration
```bash
terraform state list
```

This should show your resources are now stored in S3.

## Step 3: Normal Usage

After backend is configured, use normally:
```bash
cd modules/ecs-fargate
terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
terraform apply -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
```

## Benefits of S3 Backend

### State Locking
DynamoDB prevents multiple people from running Terraform simultaneously:
```
Error: Error acquiring the state lock
│ Lock Info:
│   ID:        a1b2c3d4-5678-90ab-cdef-1234567890ab
│   Path:      your-org-terraform-state-bucket/ecs-fargate/terraform.tfstate
│   Operation: OperationTypePlan
│   Who:       user@hostname
│   Version:   1.7.0
│   Created:   2025-01-01 12:00:00.000000000 +0000 UTC
│   Info:
```

### State Versioning
S3 versioning keeps history of state changes:
```bash
aws s3api list-object-versions --bucket your-org-terraform-state-bucket --prefix ecs-fargate/
```

### Encryption
State files are encrypted at rest using KMS:
```bash
aws s3api get-object-attributes --bucket your-org-terraform-state-bucket \
  --key ecs-fargate/terraform.tfstate --object-attributes ETag,StorageClass,ObjectSize
```

## Troubleshooting

### Backend Configuration Changes
If you need to change backend settings:
```bash
terraform init -reconfigure
```

### State Lock Issues
If state is stuck locked:
```bash
terraform force-unlock <lock-id>
```

### Multiple Environments
Each environment can use the same backend with different keys:
```hcl
# For production environment
backend "s3" {
  bucket = "your-org-terraform-state-bucket"
  key    = "ecs-fargate-prod/terraform.tfstate"  # Different key
  region = "eu-west-2"
  dynamodb_table = "terraform-state-lock"
}
```

## Security Considerations

### IAM Permissions
Users need these permissions for state management:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::your-org-terraform-state-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:eu-west-2:*:table/terraform-state-lock"
    }
  ]
}
```

### GitHub Actions
For CI/CD, the GitHub Actions OIDC role needs similar permissions to access the state backend.

## Cleanup

⚠️ **Warning**: Only delete these resources if you're completely done with Terraform:

```bash
# This will destroy ALL state management infrastructure
cd bootstrap
terraform destroy
```

This will delete:
- S3 bucket with all state files
- DynamoDB table
- KMS key

Make sure you have backups or exports of any important state before doing this.