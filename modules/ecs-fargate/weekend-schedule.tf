# Weekend-Only Scheduling Configuration for Single Region

# Weekend schedule variables
variable "enable_weekend_only" {
  description = "Enable weekend-only mode (Sat-Sun active only)"
  type        = bool
  default     = false
}

variable "destroy_albs_when_scaled_down" {
  description = "Destroy ALBs when tasks are scaled to 0 (saves ALB costs but slower startup)"
  type        = bool
  default     = false
}

# Weekend task scheduling
variable "weekend_hours_start" {
  description = "Weekend start hour (24h format, UTC)"
  type        = number
  default     = 6  # 6 AM UTC

  validation {
    condition     = var.weekend_hours_start >= 0 && var.weekend_hours_start <= 23
    error_message = "Weekend start hour must be between 0 and 23."
  }
}

variable "weekend_hours_end" {
  description = "Weekend end hour (24h format, UTC)" 
  type        = number
  default     = 22  # 10 PM UTC

  validation {
    condition     = var.weekend_hours_end >= 0 && var.weekend_hours_end <= 23
    error_message = "Weekend end hour must be between 0 and 23."
  }
}

# Weekend schedule logic
locals {
  # Weekend mode configuration
  weekend_mode_active = var.enable_weekend_only
  
  # Weekend active hours calculation: 
  # (end_hour - start_hour) × 2 days = hours per week
  # Then × 4.33 weeks = hours per month
  weekend_hours_per_day = var.weekend_hours_end - var.weekend_hours_start
  weekend_active_hours_weekly = local.weekend_hours_per_day * 2  # Saturday + Sunday
  weekend_active_hours_monthly = local.weekend_active_hours_weekly * 4.33
  
  # Cost calculations for this region
  weekend_mode_costs = var.enable_weekend_only ? {
    # Fargate costs (only when running during weekend hours)
    fargate_cpu_cost = var.desired_count * (var.cpu / 1024) * 0.04048 * local.weekend_active_hours_monthly
    fargate_memory_cost = var.desired_count * (var.memory / 1024) * 0.004445 * local.weekend_active_hours_monthly
    fargate_total = (var.desired_count * (var.cpu / 1024) * 0.04048 * local.weekend_active_hours_monthly) + (var.desired_count * (var.memory / 1024) * 0.004445 * local.weekend_active_hours_monthly)
    
    # ALB costs
    # If destroy_albs_when_scaled_down=true: ALB only runs during weekend hours
    # If destroy_albs_when_scaled_down=false: ALB runs continuously (730 hours/month)
    alb_monthly = var.destroy_albs_when_scaled_down ? (16.43 * (local.weekend_active_hours_monthly / 730)) : 16.43
    
    # Other AWS services (CloudWatch, Secrets Manager, etc.)
    other_services = 2.50
    
    # Total weekend mode cost
    total_monthly = (var.desired_count * (var.cpu / 1024) * 0.04048 * local.weekend_active_hours_monthly) + (var.desired_count * (var.memory / 1024) * 0.004445 * local.weekend_active_hours_monthly) + (var.destroy_albs_when_scaled_down ? (16.43 * (local.weekend_active_hours_monthly / 730)) : 16.43) + 2.50
  } : null
  
  # 24/7 cost calculation for comparison
  full_time_costs = {
    fargate_monthly = (var.desired_count * (var.cpu / 1024) * 0.04048 * 730) + (var.desired_count * (var.memory / 1024) * 0.004445 * 730)
    alb_monthly = 16.43
    other_services = 2.50
    total_monthly = (var.desired_count * (var.cpu / 1024) * 0.04048 * 730) + (var.desired_count * (var.memory / 1024) * 0.004445 * 730) + 16.43 + 2.50
  }
  
  # Savings calculation
  monthly_savings = var.enable_weekend_only ? (local.full_time_costs.total_monthly - local.weekend_mode_costs.total_monthly) : 0
  savings_percentage = var.enable_weekend_only ? ((local.full_time_costs.total_monthly - local.weekend_mode_costs.total_monthly) / local.full_time_costs.total_monthly * 100) : 0
}

# Weekend mode cost analysis output
output "weekend_mode_cost_analysis" {
  description = "Cost analysis for weekend-only mode vs 24/7 operation"
  value = {
    mode_enabled = var.enable_weekend_only
    region = var.aws_region
    
    schedule = var.enable_weekend_only ? {
      active_days = "Saturday, Sunday"
      active_hours = "${var.weekend_hours_start}:00 - ${var.weekend_hours_end}:00 UTC"
      hours_per_week = local.weekend_active_hours_weekly
      hours_per_month = local.weekend_active_hours_monthly
      downtime_percentage = format("%.1f%%", (1 - (local.weekend_active_hours_monthly / 730)) * 100)
    } : null
    
    costs = {
      weekend_mode = var.enable_weekend_only ? {
        fargate = format("$%.2f", local.weekend_mode_costs.fargate_total)
        alb = format("$%.2f", local.weekend_mode_costs.alb_monthly)
        other_services = format("$%.2f", local.weekend_mode_costs.other_services)
        total_monthly = format("$%.2f", local.weekend_mode_costs.total_monthly)
        total_annual = format("$%.2f", local.weekend_mode_costs.total_monthly * 12)
      } : null
      
      full_time_mode = {
        fargate = format("$%.2f", local.full_time_costs.fargate_monthly)
        alb = format("$%.2f", local.full_time_costs.alb_monthly)
        other_services = format("$%.2f", local.full_time_costs.other_services)
        total_monthly = format("$%.2f", local.full_time_costs.total_monthly)
        total_annual = format("$%.2f", local.full_time_costs.total_monthly * 12)
      }
    }
    
    savings = var.enable_weekend_only ? {
      monthly_savings = format("$%.2f", local.monthly_savings)
      annual_savings = format("$%.2f", local.monthly_savings * 12)
      percentage_savings = format("%.1f%%", local.savings_percentage)
      alb_destruction_enabled = var.destroy_albs_when_scaled_down
      additional_alb_savings = var.destroy_albs_when_scaled_down ? format("$%.2f/month", 16.43 * (1 - (local.weekend_active_hours_monthly / 730))) : "$0.00/month"
    } : null
    
    configuration = {
      desired_count = var.desired_count
      cpu_vcpu = var.cpu / 1024
      memory_gb = var.memory / 1024
      alb_created = var.create_alb
      alb_destruction = var.destroy_albs_when_scaled_down
    }
  }
}