# Terraform Outputs

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

# Load Balancer Information
output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = var.create_alb ? aws_lb.main[0].dns_name : null
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = var.create_alb ? aws_lb.main[0].zone_id : null
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = var.create_alb ? aws_lb.main[0].arn : null
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = var.create_alb ? aws_lb_target_group.main[0].arn : null
}

# ECS Information
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.main.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.main.arn
}

# Application Access
output "application_url" {
  description = "URL to access the application"
  value       = var.create_alb ? "http://${aws_lb.main[0].dns_name}" : null
}

# Custom Domain URL (if enabled)
output "custom_domain_url" {
  description = "Custom domain URL (if domain is enabled)"
  value = var.enable_domain ? (
    var.subdomain != "" ? 
    "http://${var.subdomain}.${var.domain_name}" : 
    "http://${var.domain_name}"
  ) : null
}

# Service Discovery
output "service_discovery_dns_name" {
  description = "DNS name for service discovery"
  value = var.enable_service_discovery ? (
    "${aws_service_discovery_service.main[0].name}.${aws_service_discovery_private_dns_namespace.main[0].name}"
  ) : null
}

# Security Groups
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs_tasks.id
}

# CloudWatch
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.main.name
}

# Secrets
output "secret_arn" {
  description = "ARN of the secrets manager secret"
  value       = aws_secretsmanager_secret.api_key.arn
  sensitive   = true
}

# Regional Configuration
output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "deployment_info" {
  description = "Deployment configuration information"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    region         = var.aws_region
    cluster_name   = aws_ecs_cluster.main.name
    desired_count  = var.desired_count
    container_image = var.container_image
    alb_created    = var.create_alb
    service_discovery_enabled = var.enable_service_discovery
    custom_domain_enabled = var.enable_domain
  }
}