# Import Strategy for Existing AWS Infrastructure

This document outlines the safe migration strategy for importing existing AWS ECS/Fargate infrastructure into Terraform management following 2024-2025 best practices.

## Overview

The import process uses **configuration-driven imports** with Terraform 1.7+ import blocks rather than legacy command-line imports. This approach provides better safety, reproducibility, and automation capabilities.

## Prerequisites

1. **State Management**: Ensure S3 backend is configured via bootstrap process
2. **AWS Access**: Appropriate IAM permissions for read/write operations
3. **Resource Discovery**: Complete inventory of existing AWS resources
4. **Backup Strategy**: Export current resource configurations for rollback

## Phase 1: Discovery and Planning (Week 1)

### Resource Inventory Script

```bash
#!/bin/bash
# discover-resources.sh - Inventory existing ECS infrastructure

set -e

REGION="eu-west-2"
OUTPUT_FILE="resource-inventory.json"

echo "Discovering ECS resources in region: $REGION"

# Discover ECS Clusters
aws ecs list-clusters --region $REGION --query 'clusterArns[]' --output text > clusters.txt

# For each cluster, discover services and task definitions
while IFS= read -r cluster_arn; do
    cluster_name=$(basename $cluster_arn)
    echo "Discovering services in cluster: $cluster_name"
    
    aws ecs list-services --cluster $cluster_arn --region $REGION \
        --query 'serviceArns[]' --output text > services-$cluster_name.txt
    
    # Get task definitions
    aws ecs list-task-definitions --region $REGION \
        --query 'taskDefinitionArns[]' --output text > task-definitions.txt
done < clusters.txt

echo "Resource discovery complete. Review generated files."
```

### Import Planning Configuration

```hcl
# environments/dev/imports.tf
# Configuration-driven import definitions

# Import existing ECS cluster
import {
  to = module.ecs_fargate.aws_ecs_cluster.main
  id = "production-cluster"
}

# Import existing ECS service
import {
  to = module.ecs_fargate.aws_ecs_service.app
  id = "production-cluster/api-service"
}

# Import existing task definition (latest revision)
import {
  to = module.ecs_fargate.aws_ecs_task_definition.app
  id = "api-task:5"  # Replace with actual revision number
}

# Import existing load balancer
import {
  to = module.ecs_fargate.aws_lb.main
  id = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:loadbalancer/app/api-alb/1234567890123456"
}

# Import existing target group
import {
  to = module.ecs_fargate.aws_lb_target_group.app
  id = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/api-tg/1234567890123456"
}
```

## Phase 2: Safe Import Process (Week 2)

### Step 1: Generate Configuration

```bash
# Generate Terraform configuration from existing resources
cd environments/dev
terraform plan -generate-config-out=generated-resources.tf
```

### Step 2: Configuration Alignment

```bash
# Review generated configuration
# Compare with module expectations
# Adjust variables to match existing resource settings

# Example: Align task definition settings
# If existing task uses 1024/2048, update terraform.tfvars:
# cpu = 1024
# memory = 2048
```

### Step 3: Import Execution

```bash
# Execute import process
terraform apply  # This applies the import blocks

# Verify import success
terraform plan   # Should show minimal or no changes
```

### Step 4: Cleanup and Validation

```bash
# Remove import blocks after successful import
rm imports.tf

# Run final validation
terraform plan   # Should show no changes
terraform apply  # Final state synchronization
```

## Phase 3: Incremental Migration (Week 3-4)

### Service-by-Service Approach

```hcl
# Migrate services incrementally to reduce risk
# Example: Start with non-critical services

variable "services_to_migrate" {
  description = "Services to migrate in this phase"
  type = list(object({
    name        = string
    cluster     = string
    priority    = string
    risk_level  = string
  }))
  
  default = [
    {
      name       = "api-service"
      cluster    = "production-cluster"
      priority   = "low"
      risk_level = "medium"
    }
  ]
}
```

### Blue-Green Import Strategy

```hcl
# Maintain parallel infrastructure during migration
resource "aws_ecs_service" "app_blue" {
  count = var.migration_phase == "preparation" ? 1 : 0
  
  name            = "${var.app_name}-blue"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  
  # Existing service configuration
  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_service" "app_green" {
  count = var.migration_phase != "preparation" ? 1 : 0
  
  name            = var.app_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  
  # New Terraform-managed configuration
}
```

## Risk Mitigation Strategies

### 1. Lifecycle Management

```hcl
# Prevent accidental resource destruction
resource "aws_ecs_service" "app" {
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      desired_count,  # Allow manual scaling during migration
      task_definition # Allow external updates temporarily
    ]
  }
}
```

### 2. Gradual State Management

```hcl
# Use separate state files for different migration phases
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "migration-phase-1/terraform.tfstate"  # Phase-specific state
    region = "eu-west-2"
  }
}
```

### 3. Rollback Procedures

```bash
#!/bin/bash
# rollback-migration.sh - Emergency rollback script

set -e

PHASE=$1
BACKUP_STATE="backup-states/pre-migration-${PHASE}.tfstate"

if [ -z "$PHASE" ]; then
    echo "Usage: $0 <phase>"
    exit 1
fi

echo "Rolling back migration phase: $PHASE"

# Restore previous state
aws s3 cp s3://your-terraform-state-bucket/$BACKUP_STATE \
    s3://your-terraform-state-bucket/migration-phase-${PHASE}/terraform.tfstate

# Remove imported resources from state (if needed)
# terraform state rm <resource_addresses>

echo "Rollback complete. Review infrastructure state."
```

## Validation and Testing

### 1. Import Validation Script

```bash
#!/bin/bash
# validate-import.sh - Verify successful import

set -e

echo "Running import validation..."

# Check for drift
terraform plan -detailed-exitcode
plan_exit_code=$?

if [ $plan_exit_code -eq 0 ]; then
    echo "✅ No drift detected - import successful"
elif [ $plan_exit_code -eq 2 ]; then
    echo "⚠️  Drift detected - review required"
    terraform plan
else
    echo "❌ Plan failed - investigation required"
fi

# Validate outputs
echo "Validating outputs..."
terraform output
```

### 2. Service Health Checks

```bash
#!/bin/bash
# health-check.sh - Verify service health post-import

CLUSTER_NAME=$(terraform output -raw cluster_name)
SERVICE_NAME=$(terraform output -raw service_name)

# Check service status
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Check task health
aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME
```

## Troubleshooting Common Issues

### 1. Resource Not Found Errors

```bash
# If resources are not found during import:
# 1. Verify resource exists in AWS
aws ecs describe-clusters --clusters production-cluster

# 2. Check resource ARN format
# 3. Ensure correct region is specified
```

### 2. Configuration Mismatches

```hcl
# Use lifecycle rules to handle configuration differences
resource "aws_ecs_task_definition" "app" {
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore fields that frequently change
      revision,
      tags_all
    ]
  }
}
```

### 3. State Lock Issues

```bash
# If state is locked during import:
terraform force-unlock <lock-id>

# Or use separate workspace temporarily
terraform workspace new import-phase-1
```

## Post-Import Checklist

- [ ] All resources successfully imported
- [ ] No drift detected in terraform plan
- [ ] Service health checks passing
- [ ] Monitoring and alerting functional
- [ ] Documentation updated
- [ ] Team training completed on new workflows
- [ ] Rollback procedures tested
- [ ] CI/CD pipelines validated

## Timeline and Milestones

| Phase | Duration | Milestone | Success Criteria |
|-------|----------|-----------|------------------|
| 1 | Week 1 | Discovery Complete | Full resource inventory |
| 2 | Week 2 | Import Complete | No terraform plan drift |
| 3 | Week 3-4 | Migration Complete | All services managed by Terraform |
| 4 | Week 5 | Validation Complete | Full CI/CD pipeline operational |

## Additional Resources

- [Terraform Import Documentation](https://developer.hashicorp.com/terraform/cli/import)
- [AWS ECS Import Guide](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#import)
- [Configuration-driven Import](https://developer.hashicorp.com/terraform/language/import)