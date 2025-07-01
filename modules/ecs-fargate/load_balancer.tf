# Load Balancer Infrastructure

# Application Load Balancer (conditional creation)
resource "aws_lb" "main" {
  count = var.create_alb ? 1 : 0
  
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# Target Group (conditional creation)
resource "aws_lb_target_group" "main" {
  count = var.create_alb ? 1 : 0
  
  name        = "${local.name_prefix}-tg"
  port        = var.target_group_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

# Load Balancer Listener (conditional creation)
resource "aws_lb_listener" "main" {
  count = var.create_alb ? 1 : 0
  
  load_balancer_arn = aws_lb.main[0].arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-listener"
  })
}