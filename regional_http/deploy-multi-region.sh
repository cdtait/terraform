#!/bin/bash

# Multi-Region Deployment Script for FMP MCP Server
# This script deploys the same infrastructure to multiple regions using separate terraform state files

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"

# Default region configurations
declare -A REGION_CONFIGS
REGION_CONFIGS=(
    ["eu-west-1"]="172.31.0.0/16|eu-west-1a,eu-west-1b,eu-west-1c|172.31.0.0/20,172.31.16.0/20,172.31.32.0/20"
    ["eu-west-2"]="172.32.0.0/16|eu-west-2a,eu-west-2b,eu-west-2c|172.32.0.0/20,172.32.16.0/20,172.32.32.0/20"
    ["us-east-1"]="172.33.0.0/16|us-east-1a,us-east-1b,us-east-1c|172.33.0.0/20,172.33.16.0/20,172.33.32.0/20"
    ["us-west-2"]="172.34.0.0/16|us-west-2a,us-west-2b,us-west-2c|172.34.0.0/20,172.34.16.0/20,172.34.32.0/20"
    ["ap-southeast-1"]="172.35.0.0/16|ap-southeast-1a,ap-southeast-1b,ap-southeast-1c|172.35.0.0/20,172.35.16.0/20,172.35.32.0/20"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
    plan REGION          - Plan deployment for a specific region
    apply REGION         - Apply deployment for a specific region
    destroy REGION       - Destroy deployment for a specific region
    list-regions         - List available regions and their configurations
    generate-tfvars REGION - Generate terraform.tfvars file for a region
    deploy-all           - Deploy to all configured regions
    destroy-all          - Destroy all regional deployments
    status               - Show deployment status for all regions

OPTIONS:
    -h, --help          - Show this help message
    -v, --verbose       - Enable verbose output
    --dry-run           - Show what would be done without executing
    --auto-approve      - Auto approve terraform apply (use with caution)

REGION EXAMPLES:
    eu-west-1, eu-west-2, us-east-1, us-west-2, ap-southeast-1

EXAMPLES:
    $0 plan eu-west-1                    # Plan deployment for EU West 1
    $0 apply eu-west-2                   # Deploy to EU West 2
    $0 deploy-all                        # Deploy to all regions
    $0 generate-tfvars us-east-1         # Generate config for US East 1
    $0 status                            # Show status of all deployments

EOF
}

# Function to generate terraform.tfvars for a specific region
generate_tfvars() {
    local region="$1"
    local output_file="$2"
    
    if [[ ! "${REGION_CONFIGS[$region]+isset}" ]]; then
        log_error "Unknown region: $region"
        log_info "Available regions: ${!REGION_CONFIGS[*]}"
        return 1
    fi
    
    # Parse region configuration
    IFS='|' read -r vpc_cidr azs subnet_cidrs <<< "${REGION_CONFIGS[$region]}"
    
    # Convert comma-separated values to terraform list format
    az_list=$(echo "$azs" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')
    subnet_list=$(echo "$subnet_cidrs" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')
    
    cat > "$output_file" << EOF
# Single-Region Deployment Configuration for ${region}
# Generated on $(date)

# Core Settings
project_name = "fmp-mcp"
environment  = "dev"
aws_region   = "${region}"

# Network Configuration
vpc_cidr             = "${vpc_cidr}"
availability_zones   = [${az_list}]
subnet_cidrs        = [${subnet_list}]

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

# Domain Configuration (disabled by default)
enable_domain = false
domain_name   = "cdtait.cloud"
subdomain     = "fmp-${region}"
enable_ipv6   = false

# Security - API Key (CHANGE THIS!)
fmp_api_key = "\${var.fmp_api_key_from_env}"

# Optional cluster name override
# cluster_name = "fmp-mcp-${region}-cluster"
EOF
    
    log_success "Generated terraform.tfvars for $region: $output_file"
}

# Function to initialize terraform for a region
init_terraform() {
    local region="$1"
    
    log_info "Initializing Terraform for region: $region"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize terraform (will use region-specific state via -state parameters)
    terraform init -reconfigure || {
        log_error "Failed to initialize Terraform for $region"
        return 1
    }
    
    log_success "Terraform initialized for $region"
}


# Function to plan deployment for a region
plan_region() {
    local region="$1"
    local tfvars_file="terraform-${region}.tfvars"
    
    log_info "Planning deployment for region: $region"
    
    # Generate tfvars file only if it doesn't exist
    if [[ ! -f "$tfvars_file" ]]; then
        log_info "Generating tfvars file for $region"
        generate_tfvars "$region" "$tfvars_file"
    else
        log_info "Using existing tfvars file: $tfvars_file"
    fi
    
    # Initialize terraform
    init_terraform "$region"
    
    # Run terraform plan with region-specific state
    local state_file="terraform-${region}.tfstate"
    terraform plan -state="$state_file" -var-file="$tfvars_file" -out="terraform-${region}.tfplan"
    
    log_success "Plan completed for $region"
}

# Function to apply deployment for a region
apply_region() {
    local region="$1"
    local auto_approve="$2"
    local tfvars_file="terraform-${region}.tfvars"
    local plan_file="terraform-${region}.tfplan"
    
    log_info "Applying deployment for region: $region"
    
    # Check if plan file exists
    if [[ ! -f "$plan_file" ]]; then
        log_warning "No plan file found for $region. Running plan first..."
        plan_region "$region"
    fi
    
    # Apply terraform with region-specific state
    local state_file="terraform-${region}.tfstate"
    if [[ "$auto_approve" == "true" ]]; then
        terraform apply -state="$state_file" -state-out="$state_file" -auto-approve "$plan_file"
    else
        terraform apply -state="$state_file" -state-out="$state_file" "$plan_file"
    fi
    
    log_success "Deployment completed for $region"
    
    # Show outputs
    log_info "Deployment outputs for $region:"
    if [[ -f "terraform-${region}.tfstate" ]]; then
        terraform output -state="terraform-${region}.tfstate" -json | jq .
    fi
}

# Function to destroy deployment for a region
destroy_region() {
    local region="$1"
    local auto_approve="$2"
    local tfvars_file="terraform-${region}.tfvars"
    
    log_warning "Destroying deployment for region: $region"
    
    # Check if tfvars file exists
    if [[ ! -f "$tfvars_file" ]]; then
        log_warning "No tfvars file found for $region. Generating..."
        generate_tfvars "$region" "$tfvars_file"
    fi
    
    # Initialize terraform
    init_terraform "$region"
    
    # Destroy terraform with region-specific state
    local state_file="terraform-${region}.tfstate"
    if [[ "$auto_approve" == "true" ]]; then
        terraform destroy -state="$state_file" -state-out="$state_file" -auto-approve -var-file="$tfvars_file"
    else
        terraform destroy -state="$state_file" -state-out="$state_file" -var-file="$tfvars_file"
    fi
    
    log_success "Destruction completed for $region"
}

# Function to show deployment status
show_status() {
    log_info "Deployment Status Summary"
    echo "=================================="
    
    for region in "${!REGION_CONFIGS[@]}"; do
        local state_file="terraform-${region}.tfstate"
        local tfvars_file="terraform-${region}.tfvars"
        
        echo -e "\n🌍 Region: ${BLUE}$region${NC}"
        
        # Check if state file exists (try region-specific first, then default)
        local actual_state_file=""
        if [[ -f "$state_file" ]]; then
            actual_state_file="$state_file"
        elif [[ "$region" == "eu-west-2" && -f "terraform.tfstate" ]]; then
            actual_state_file="terraform.tfstate"
        fi
        
        if [[ -n "$actual_state_file" ]]; then
            # Try to get outputs if state has resources
            if terraform show -json "$actual_state_file" 2>/dev/null | jq -e '.values.root_module.resources | length > 0' >/dev/null 2>&1; then
                echo -e "   Status: ${GREEN}DEPLOYED${NC}"
                # Try to get ALB URL
                if command -v jq >/dev/null 2>&1; then
                    local alb_url=$(terraform output -state="$actual_state_file" -json 2>/dev/null | jq -r '.application_url.value // empty' 2>/dev/null)
                    if [[ -n "$alb_url" && "$alb_url" != "null" ]]; then
                        echo -e "   ALB URL: ${BLUE}$alb_url${NC}"
                    fi
                fi
                if [[ "$actual_state_file" != "$state_file" ]]; then
                    echo -e "   Note: ${YELLOW}Using default state file${NC}"
                fi
            else
                echo -e "   Status: ${YELLOW}STATE EXISTS (empty)${NC}"
            fi
        else
            echo -e "   Status: ${RED}NOT DEPLOYED${NC}"
        fi
        
        # Check if tfvars file exists
        if [[ -f "$tfvars_file" ]]; then
            echo -e "   Config: ${GREEN}✓${NC} tfvars file exists"
        else
            echo -e "   Config: ${YELLOW}✗${NC} tfvars file missing"
        fi
    done
    
    echo -e "\n=================================="
}

# Function to list available regions
list_regions() {
    log_info "Available Regions and Configurations"
    echo "====================================="
    
    for region in "${!REGION_CONFIGS[@]}"; do
        IFS='|' read -r vpc_cidr azs subnet_cidrs <<< "${REGION_CONFIGS[$region]}"
        echo -e "\n🌍 ${BLUE}$region${NC}"
        echo "   VPC CIDR: $vpc_cidr"
        echo "   AZs: $azs"
        echo "   Subnets: $subnet_cidrs"
    done
    
    echo -e "\n====================================="
}

# Main execution logic
main() {
    local command="$1"
    local region="$2"
    local auto_approve="false"
    local dry_run="false"
    local verbose="false"
    
    # Commands that don't require a region
    case "$command" in
        status|list-regions|deploy-all|destroy-all)
            shift 1
            ;;
        *)
            shift 2 2>/dev/null || true
            ;;
    esac
    
    # Parse additional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-approve)
                auto_approve="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                set -x
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate terraform is installed
    if ! command -v terraform >/dev/null 2>&1; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Change to terraform directory
    cd "$TERRAFORM_DIR"
    
    case "$command" in
        plan)
            if [[ -z "$region" ]]; then
                log_error "Region required for plan command"
                show_usage
                exit 1
            fi
            plan_region "$region"
            ;;
        apply)
            if [[ -z "$region" ]]; then
                log_error "Region required for apply command"
                show_usage
                exit 1
            fi
            apply_region "$region" "$auto_approve"
            ;;
        destroy)
            if [[ -z "$region" ]]; then
                log_error "Region required for destroy command"
                show_usage
                exit 1
            fi
            destroy_region "$region" "$auto_approve"
            ;;
        generate-tfvars)
            if [[ -z "$region" ]]; then
                log_error "Region required for generate-tfvars command"
                show_usage
                exit 1
            fi
            generate_tfvars "$region" "terraform-${region}.tfvars"
            ;;
        deploy-all)
            log_info "Deploying to all regions: ${!REGION_CONFIGS[*]}"
            for region in "${!REGION_CONFIGS[@]}"; do
                log_info "Deploying to $region..."
                apply_region "$region" "$auto_approve"
            done
            log_success "All regions deployed successfully"
            ;;
        destroy-all)
            log_warning "Destroying all regional deployments"
            if [[ "$auto_approve" != "true" ]]; then
                read -p "Are you sure you want to destroy ALL regional deployments? (yes/no): " confirm
                if [[ "$confirm" != "yes" ]]; then
                    log_info "Operation cancelled"
                    exit 0
                fi
            fi
            for region in "${!REGION_CONFIGS[@]}"; do
                log_warning "Destroying $region..."
                destroy_region "$region" "true"
            done
            log_success "All regions destroyed"
            ;;
        status)
            show_status
            ;;
        list-regions)
            list_regions
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check for help flag in any position
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_usage
        exit 0
    fi
done

# Ensure at least one argument is provided
if [[ $# -eq 0 ]]; then
    log_error "No command provided"
    show_usage
    exit 1
fi

# Execute main function
main "$@"