resource "aws_autoscaling_group" "web" {
  name                      = "${local.project}-WEB-ASG"
  min_size                  = 2
  desired_capacity          = var.web_desired_capacity
  max_size                  = 4
  vpc_zone_identifier       = [for subnet in aws_subnet.app : subnet.id]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.project}-WEB"
      Tier = "web"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
resource "aws_autoscaling_group" "was" {
  name                      = "${local.project}-WAS-ASG"
  min_size                  = 2
  desired_capacity          = var.was_desired_capacity
  max_size                  = 4
  vpc_zone_identifier       = [for subnet in aws_subnet.app : subnet.id]
  target_group_arns         = [aws_lb_target_group.was.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 240
  launch_template {
    id      = aws_launch_template.was.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.project}-WAS"
      Tier = "was"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${local.project}-WEB-CPU-50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
resource "aws_autoscaling_policy" "was_cpu" {
  name                   = "${local.project}-WAS-CPU-50"
  autoscaling_group_name = aws_autoscaling_group.was.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}