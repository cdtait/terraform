# Single-Region Deployment Configuration for eu-west-2
# Generated on Mon 23 Jun 09:01:17 BST 2025

# Core Settings
project_name = "fmp-mcp"
environment  = "dev"
aws_region   = "eu-west-2"

# Network Configuration
vpc_cidr             = "172.32.0.0/16"
availability_zones   = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
subnet_cidrs        = ["172.32.0.0/20", "172.32.16.0/20", "172.32.32.0/20"]

# Container Configuration
container_image = "ghcr.io/cdtait/fmp-mcp-server:latest"
container_port  = 8001
cpu             = 1024
memory          = 3072
desired_count   = 2

# Load Balancer Configuration
create_alb          = true
alb_port            = 80
target_group_port   = 8000
health_check_path   = "/health"

# Container Environment
container_environment = {
  PORT      = "8001"
  STATELESS = "true"
  TRANSPORT = "streamable-http"
}

# Service Discovery
enable_service_discovery             = true
service_discovery_ttl               = 60
service_discovery_failure_threshold = 1

# Domain Configuration (enabled for latency-based routing)
enable_domain = true
domain_name   = "cdtait.cloud"
subdomain     = "fmp"
enable_ipv6   = false

# Weekend Scheduling (Cost Optimization)
enable_weekend_only               = false  # Set to true for weekend-only operation
destroy_albs_when_scaled_down    = false  # Set to true for maximum cost savings
weekend_hours_start              = 6      # 6 AM UTC
weekend_hours_end                = 22     # 10 PM UTC


# Optional cluster name override
# cluster_name = "fmp-mcp-eu-west-2-cluster"
