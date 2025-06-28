# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Architecture

This repository contains Terraform infrastructure for deploying MCP (Model Context Protocol) servers on AWS ECS Fargate with multi-region capabilities.

### Main Component:
- **`regional_http/`**: Production-ready modular Terraform configuration 

### Primary Architecture (`regional_http/`):
- **Container Platform**: AWS ECS Fargate clusters with service discovery
- **Networking**: Dedicated VPCs per region with 3-AZ public subnets  
- **Load Balancing**: Application Load Balancer with health checks
- **Global Routing**: Route53 latency-based routing across 5 regions
- **Cost Optimization**: Weekend-only scheduling (87-92% cost savings)

## Essential Commands

### Single Region Operations
```bash
# Initialize and deploy to specific region
terraform init
terraform plan -var-file="terraform-eu-west-1.tfvars"
terraform apply -var-file="terraform-eu-west-1.tfvars"
terraform destroy -var-file="terraform-eu-west-1.tfvars"
```

### Multi-Region Management
```bash
# Deploy to all configured regions
./deploy-multi-region.sh deploy-all

# Check status across regions
./deploy-multi-region.sh status

# Region-specific operations
./deploy-multi-region.sh plan eu-west-1
./deploy-multi-region.sh apply eu-west-2
./deploy-multi-region.sh destroy us-east-1
```

### Monitoring and Health Checks
```bash
# Check ECS service status
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name)

# View application logs
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Test application endpoint
curl $(terraform output -raw application_url)/health
```

## File Organization

### Core Infrastructure Files:
- **`main.tf`**: Provider config, locals, and tagging strategy
- **`variables.tf`**: 163+ configurable variables
- **`outputs.tf`**: 33 outputs for integration and monitoring
- **`ecs.tf`**: ECS cluster, services, and task definitions
- **`network.tf`**: VPC, subnets, security groups, and routing
- **`load_balancer.tf`**: ALB configuration with conditional creation
- **`iam.tf`**: Execution and task role definitions
- **`secrets.tf`**: AWS Secrets Manager integration
- **`service_discovery.tf`**: AWS Cloud Map service registry
- **`route53.tf`**: DNS and global routing configuration
- **`weekend-schedule.tf`**: Cost optimization scheduling logic

### Configuration Templates:
- **`terraform.tfvars.example`**: Complete configuration template
- **`terraform-{region}.tfvars`**: Region-specific variable files

### Automation:
- **`deploy-multi-region.sh`**: Multi-region deployment automation script

## Key Configuration Patterns

### Variable-Driven Infrastructure
The codebase uses extensive variable configuration. Always check `variables.tf` for available options and use region-specific `.tfvars` files.

### Multi-Region State Management
Each region maintains separate Terraform state. The deployment script handles workspace/state switching automatically.

### Cost Optimization Features
The infrastructure includes advanced scheduling for weekend-only operation. Check `weekend-schedule.tf` for cost optimization logic.

### Container Configuration
ECS tasks default to 1 vCPU and 3GB memory with desired count of 2. Scale by modifying variables:
```bash
terraform apply -var="desired_count=4" -var="cpu=2048" -var="memory=4096"
```

## Security Architecture

- **IAM Roles**: Separate execution and task roles with least-privilege access
- **Network Security**: Security groups with minimal required access
- **Secrets Management**: AWS Secrets Manager for sensitive configuration
- **VPC Isolation**: Dedicated VPCs per region with controlled routing

## Development Workflow

1. **Setup**: Copy `terraform.tfvars.example` and customize for your environment
2. **Planning**: Use deployment script for multi-region planning and validation
3. **Deployment**: Script handles state management and region coordination
4. **Monitoring**: Use Terraform outputs to access service URLs and monitoring resources
5. **Scaling**: Modify variables for capacity or performance adjustments

## Important Notes

- No traditional build/lint/test commands - this is pure infrastructure code
- Multi-region deployment requires careful state management (handled by script)
- Weekend scheduling can dramatically reduce costs but requires planning
- The codebase assumes AWS CLI is configured with appropriate permissions
- Custom domains require existing Route53 hosted zones