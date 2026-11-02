output "app_url" {
  description = "Open this in your browser (the load balancer)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "asg_name" {
  description = "Auto Scaling group name"
  value       = aws_autoscaling_group.app.name
}

output "list_servers_command" {
  description = "Shows the servers, their AZ and health"
  value       = "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.app.name} --query \"AutoScalingGroups[0].Instances[].[InstanceId,AvailabilityZone,HealthStatus]\" --output table"
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}

output "db_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}
