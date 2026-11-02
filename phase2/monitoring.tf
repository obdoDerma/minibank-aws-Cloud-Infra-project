# MONITORING - CloudWatch alarms that email you through SNS.
# After apply, AWS sends a "Subscription Confirmation" email: click the link,
# or you will never receive alarms.

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Example alarm (done for you): any server failing the load balancer health check.
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project}-unhealthy-hosts"
  alarm_description   = "At least one web server is failing the ALB health check"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# =====================================================================
# YOUR TASK: write an alarm for HIGH CPU on the Auto Scaling group.
# Copy the alarm above and change only what is needed:
#
#   resource name  : "high_cpu"
#   alarm_name     : "${var.project}-high-cpu"
#   namespace      : "AWS/EC2"
#   metric_name    : "CPUUtilization"
#   statistic      : "Average"
#   period         : 300         (5 minutes)
#   evaluation_periods : 2       (= 10 minutes above threshold)
#   threshold      : 80
#   dimensions     : { AutoScalingGroupName = aws_autoscaling_group.app.name }
#
# Then run:  terraform fmt  ->  terraform validate  ->  terraform plan
# The plan should show exactly 1 new resource. Send it to Claude for review.
# =====================================================================
