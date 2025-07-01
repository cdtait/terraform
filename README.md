# Terraform ECS Fargate Infrastructure

Enterprise-grade Terraform infrastructure for deploying MCP (Model Context Protocol) servers on AWS ECS Fargate, following 2024-2025 best practices.

## 🏗️ Architecture

- **Environment-Based Configuration**: Simple terraform.tfvars files per environment
- **Modular Design**: Complete ECS Fargate infrastructure in reusable module
- **State Management**: S3 backend with DynamoDB locking and KMS encryption
- **CI/CD Integration**: GitHub Actions workflows with OIDC authentication
- **Default MCP Server**: Ships with mcp/duckduckgo Docker image
- **Security**: Secrets Manager integration and least-privilege IAM

## 🚀 Quick Start

### 1. Bootstrap State Management

```bash
# Copy and customize bootstrap configuration
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your unique bucket name

# Create S3 bucket and DynamoDB table
terraform init
terraform apply
```

### 2. Deploy Infrastructure

```bash
# Deploy to EU West 2 environment
cd modules/ecs-fargate
terraform init
terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
terraform apply -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"
```

### 3. Set Up CI/CD (Optional)

1. Configure GitHub repository secrets:
   - `AWS_ROLE_ARN`: OIDC role for environments
2. Set repository variables:
   - `AWS_REGION`: Target AWS region (default: eu-west-2)

## 📁 Repository Structure

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
│       └── *.tf               # All infrastructure components
├── bootstrap/                 # State management setup
│   ├── terraform.tfvars.example  # Bootstrap template
│   └── *.tf                   # S3 and DynamoDB resources
├── .github/workflows/         # CI/CD pipelines
└── docs/                      # Documentation
```

## 🔧 Configuration

### Default Configuration

The infrastructure comes with sensible defaults:

- **Container**: MCP DuckDuckGo server (mcp/duckduckgo:latest)
- **Compute**: 1024 CPU / 3072 MB memory
- **Scaling**: 2 desired tasks
- **Region**: EU West 2 (eu-west-2)
- **Load Balancer**: Application Load Balancer with health checks

### Customization

Override defaults in your environment's `terraform.tfvars`:

```hcl
# Custom container image
container_image = "your-custom-mcp-server:latest"

# Different resource allocation
cpu = 512
memory = 1024
desired_count = 1

# Enable domain with Route53
enable_domain = true
domain_name = "your-domain.com"
subdomain = "mcp"
```

## 🔄 CI/CD Pipeline

### Pull Request Workflow

- **Format Check**: Terraform format validation
- **Plan Generation**: Plans for terraform-eu-west-2 environment
- **Comment Integration**: Plan results posted to PR
- **Artifact Storage**: Plan files saved for deployment

### Deployment Workflow

- **Environment Deploy**: Auto-deploy on main branch merge
- **Manual Approval**: GitHub environment protection rules
- **Drift Detection**: Daily monitoring with GitHub Issues
- **State Management**: Centralized S3 backend with locking

## 📊 Monitoring

### Drift Detection

Automated daily checks detect infrastructure drift:

```bash
# Manual drift check
cd modules/ecs-fargate
terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars" -detailed-exitcode
```

### Health Monitoring

```bash
# Check ECS service status (from modules/ecs-fargate)
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name)

# View application logs
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow

# Test application endpoint
curl $(terraform output -raw application_url)
```

## 🔒 Security

### OIDC Authentication

GitHub Actions use OIDC instead of long-lived credentials:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION || 'eu-west-2' }}
```

### Secrets Management

Sensitive data stored in AWS Secrets Manager:

```hcl
secrets = [
  {
    name      = "DATABASE_URL"
    valueFrom = "arn:aws:secretsmanager:region:account:secret:name"
  }
]
```

## 📚 Documentation

- **[Backend Setup](docs/BACKEND_SETUP.md)**: S3 state management configuration
- **[Import Strategy](docs/IMPORT_STRATEGY.md)**: Migrating existing AWS resources
- **[CLAUDE.md](CLAUDE.md)**: AI assistant guidance and patterns
- **[Research](docs/terraform_research.md)**: Best practices research and rationale

## 🛠️ Development Workflow

### Local Development

```bash
# Plan changes
cd modules/ecs-fargate
terraform plan -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"

# Apply changes
terraform apply -var-file="../../environments/terraform-eu-west-2/terraform.tfvars"

# Import existing resources
terraform import aws_ecs_cluster.main production-cluster
```

### Adding New Environments

1. Create new directory: `mkdir environments/terraform-us-east-1`
2. Copy template: `cp environments/template/terraform.tfvars environments/terraform-us-east-1/`
3. Edit `terraform.tfvars` with region-specific settings
4. Add environment to GitHub Actions matrix in `.github/workflows/`

## 🔄 Migration from Legacy

If migrating from the legacy `regional_http/` structure:

1. Review [Import Strategy](docs/IMPORT_STRATEGY.md)
2. Use configuration-driven imports
3. Validate with drift detection
4. Test rollback procedures

## 📋 Requirements

- **Terraform**: >= 1.7.0
- **AWS Provider**: >= 5.0
- **AWS CLI**: Configured with appropriate permissions
- **GitHub**: Repository with Actions enabled

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with proper testing
4. Submit pull request with plan output
5. Ensure CI/CD pipeline passes

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

- **Issues**: Use GitHub Issues for bug reports
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check `docs/` directory for detailed guides