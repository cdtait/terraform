# Service Discovery

# AWS Cloud Map Private DNS Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  count = var.enable_service_discovery ? 1 : 0
  
  name = "${local.name_prefix}-services"
  vpc  = aws_vpc.main.id
  
  description = "Service discovery namespace for ${var.project_name} ${var.environment} services in ${var.aws_region}"

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-namespace"
  })
}

# AWS Cloud Map Service
resource "aws_service_discovery_service" "main" {
  count = var.enable_service_discovery ? 1 : 0
  
  name = "${var.project_name}-${var.aws_region}-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main[0].id
    
    dns_records {
      ttl  = var.service_discovery_ttl
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = var.service_discovery_failure_threshold
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-service-discovery"
  })
}