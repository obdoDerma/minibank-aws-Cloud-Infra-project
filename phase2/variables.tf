# Inputs. Change values in terraform.tfvars, not here.

variable "project" {
  type    = string
  default = "minibank"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public: ONLY the load balancer lives here now"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_subnets" {
  description = "NEW private app tier: web servers, no public IPs"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "db_subnets" {
  description = "Private DB tier: no route out at all"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min" {
  type    = number
  default = 2
}

variable "asg_desired" {
  type    = number
  default = 2
}

variable "asg_max" {
  type    = number
  default = 4
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Standby DB in the 2nd AZ. Set false to halve DB cost on a quick session"
  type        = bool
  default     = true
}

variable "enable_ssm_endpoints" {
  description = "Shell access to the private servers (adds ~$0.04/hour). Off = immutable servers"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email for budget + CloudWatch alarms"
  type        = string
}

variable "budget_limit_usd" {
  type    = string
  default = "3"
}
