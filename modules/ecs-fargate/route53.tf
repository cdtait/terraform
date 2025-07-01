# Route53 Configuration for Multi-Region Latency-Based Routing

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  count        = var.enable_domain ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# A record with latency-based routing for load balancer
resource "aws_route53_record" "main" {
  count   = var.enable_domain && var.create_alb ? 1 : 0
  
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "A"
  
  # Latency-based routing configuration
  set_identifier = var.aws_region
  
  latency_routing_policy {
    region = var.aws_region
  }

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}

# Optional: AAAA record with latency-based routing for IPv6 support
resource "aws_route53_record" "ipv6" {
  count   = var.enable_domain && var.enable_ipv6 && var.create_alb ? 1 : 0
  
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  type    = "AAAA"
  
  # Latency-based routing configuration
  set_identifier = "${var.aws_region}-ipv6"
  
  latency_routing_policy {
    region = var.aws_region
  }

  alias {
    name                   = aws_lb.main[0].dns_name
    zone_id                = aws_lb.main[0].zone_id
    evaluate_target_health = true
  }
}