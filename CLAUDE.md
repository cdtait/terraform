# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Architecture

This repository contains enterprise-grade Terraform infrastructure for deploying MCP (Model Context Protocol) servers on AWS ECS Fargate following 2024-2025 best practices.

### Repository Structure:
```
terraform/
├── environments/
│   ├── template/              # Reference configuration
│   │   └── terraform.tfvars   # Template variables
│   └── terraform-eu-west-2/   # EU West 2 environment
│       └── terraform.tfvars   # Environment-specific variables
├── modules/
│   └── ecs-fargate/           # Complete ECS Fargate infrastructure
│       ├── main.tf            # Infrastructure resources
│       ├── variables.tf       # Input variables
│       ├── outputs.tf         # Output values
│       └── *.tf               # All other infrastructure files
├── bootstrap/                 # State management setup
├── .github/workflows/         # CI/CD pipelines
└── docs/                      # Documentation
```

### Architecture Features:
- **Environment Separation**: Environment-specific directories with auto-loading tfvars
- **Modular Design**: Reusable modules for different infrastructure components
- **State Management**: S3 backend with DynamoDB locking and KMS encryption
- **CI/CD Integration**: GitHub Actions workflows with OIDC authentication
- **Cost Optimization**: Development uses Fargate Spot (70% savings)
- **Security**: Secrets Manager integration and least-privilege IAM

## Essential Commands

### Bootstrap (Run Once)
```bash
# Set up S3 bucket and DynamoDB for state management
cd bootstrap
terraform init
terraform apply
```

### Environment Operations
```bash
# Deploy to EU West 2
cd modules/ecs-fargate
terraform init
terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
terraform apply -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
terraform destroy -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"

# Create new environment
mkdir environments/terraform-us-east-1
cp environments/template/terraform.tfvars environments/terraform-us-east-1/
# Edit the new terraform.tfvars file with region-specific settings
```

## File Organization

### Environment Structure:
- **`modules/ecs-fargate/`**: Complete ECS Fargate infrastructure
  - `main.tf`: Infrastructure resources and provider config
  - `variables.tf`: All variable definitions  
  - `outputs.tf`: Infrastructure outputs
  - All other `.tf` files for networking, security, etc.
- **`environments/template/`**: Reference configuration template
  - `terraform.tfvars`: Template with all available variables
- **`environments/terraform-{region}/`**: Environment-specific configurations
  - `terraform.tfvars`: Region and environment-specific variable values

### Module Structure:
- **`modules/ecs-fargate/`**: Core ECS Fargate infrastructure
  - Complete ECS cluster, service, and task definitions
  - Load balancer and networking components
  - Auto-scaling and monitoring configurations
- **`modules/networking/`**: VPC and network components
- **`modules/monitoring/`**: CloudWatch and observability

### Bootstrap Infrastructure:
- **`bootstrap/`**: State management infrastructure
  - S3 bucket for Terraform state
  - DynamoDB table for state locking
  - KMS encryption for state security

### CI/CD Workflows:
- **`.github/workflows/terraform-plan.yml`**: PR validation and planning
- **`.github/workflows/terraform-apply.yml`**: Deployment with approval gates
- **`.github/workflows/terraform-drift-detection.yml`**: Daily drift monitoring

## Key Configuration Patterns

### Environment-Specific Configuration
Each environment uses optimized settings:
- **Development**: Fargate Spot instances, minimal logging retention
- **Production**: Standard Fargate, extended logging, auto-scaling enabled

### State Management
- **Remote Backend**: S3 with DynamoDB locking
- **Encryption**: KMS-encrypted state files
- **Isolation**: Separate state files per environment

### Security Best Practices
- **OIDC Authentication**: GitHub Actions use OIDC instead of long-lived keys
- **Least Privilege IAM**: Minimal required permissions
- **Secrets Management**: AWS Secrets Manager integration
- **Network Isolation**: VPC with private subnets and security groups

## Development Workflow

### Initial Setup
1. **Bootstrap State Management**: Run `terraform apply` in `bootstrap/` directory
2. **Configure Environments**: Update `terraform.tfvars` in environment directories
3. **Set Up GitHub Secrets**: Configure AWS OIDC role ARNs and region variables

### CI/CD Pipeline
1. **Pull Request Flow**: 
   - Automatic format check, validation, and planning
   - Plan results posted as PR comments
   - Drift detection for all environments
2. **Deployment Flow**:
   - Dev environment: Auto-deploy on main branch
   - Production: Manual approval required
   - Plan artifacts saved for audit trail

### Local Development
1. **Environment Planning**: `cd modules/ecs-fargate && terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"`
2. **Apply Changes**: `terraform apply -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"`
3. **Import Existing Resources**: Use import blocks for safe resource adoption
4. **New Environment**: Copy `environments/template/terraform.tfvars` to new environment directory

### Monitoring and Maintenance
1. **Drift Detection**: Automated daily checks with GitHub Issues
2. **State Management**: Centralized S3 backend with locking
3. **Security**: Regular OIDC token rotation and access reviews

## Amazon Web Services
### Monitoring and Health Checks
```bash
# Check ECS service status
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name)

# View application logs
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Test application endpoint
curl $(terraform output -raw application_url)/health
```

## Important Notes

- No traditional build/lint/test commands - this is pure infrastructure code
- Multi-region deployment requires careful state management (handled by script)
- Weekend scheduling can dramatically reduce costs but requires planning
- The codebase assumes AWS CLI is configured with appropriate permissions
- Custom domains require existing Route53 hosted zones