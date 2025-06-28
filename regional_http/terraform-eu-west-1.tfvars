# Single-Region Deployment Configuration for eu-west-1
# Generated on Mon 23 Jun 16:39:09 BST 2025

# Core Settings
project_name = "fmp-mcp"
environment  = "dev"
aws_region   = "eu-west-1"

# Network Configuration
vpc_cidr             = "172.31.0.0/16"
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
subnet_cidrs        = ["172.31.0.0/20", "172.31.16.0/20", "172.31.32.0/20"]

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


# Optional cluster name override
# cluster_name = "fmp-mcp-eu-west-1-cluster"
