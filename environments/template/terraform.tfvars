# Template Configuration - Copy and customize for each environment
# Generated from regional_http configuration

# Core Settings
project_name = "mcp-server"
environment  = "dev"
aws_region   = "eu-west-2"

# Network Configuration
vpc_cidr             = "172.32.0.0/16"
availability_zones   = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
subnet_cidrs        = ["172.32.0.0/20", "172.32.16.0/20", "172.32.32.0/20"]

# Container Configuration
container_image = "nginx:latest"  # Replace with your image
container_port  = 80
cpu             = 1024
memory          = 3072
desired_count   = 2

# Load Balancer Configuration
create_alb          = true
alb_port            = 80
target_group_port   = 80
health_check_path   = "/health"

# Container Environment Variables
container_environment = {
  NODE_ENV = "development"
  PORT     = "80"
}

# Service Discovery
enable_service_discovery             = true
service_discovery_ttl               = 60
service_discovery_failure_threshold = 1

# Domain Configuration
enable_domain = false  # Set to true if you have a domain
domain_name   = "your-domain.com"
subdomain     = "api"
enable_ipv6   = false

# Weekend Scheduling (Cost Optimization)
enable_weekend_only               = false  # Set to true for weekend-only operation
destroy_albs_when_scaled_down    = false  # Set to true for maximum cost savings
weekend_hours_start              = 6      # 6 AM UTC
weekend_hours_end                = 22     # 10 PM UTC

# Optional cluster name override
# cluster_name = "custom-cluster-name"