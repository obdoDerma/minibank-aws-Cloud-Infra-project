# Values printed after `terraform apply` (and any time with `terraform output`).

output "web_url" {
  description = "Open this in your browser"
  value       = "http://${aws_instance.web.public_dns}"
}

output "instance_id" {
  description = "EC2 instance ID (used by SSM)"
  value       = aws_instance.web.id
}

output "ssm_connect_command" {
  description = "Run this to get a shell on the server"
  value       = "aws ssm start-session --target ${aws_instance.web.id}"
}

output "db_endpoint" {
  description = "RDS hostname (only reachable from inside the VPC)"
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager secret that holds the DB password"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "assets_bucket" {
  description = "Private S3 bucket name"
  value       = aws_s3_bucket.assets.bucket
}
