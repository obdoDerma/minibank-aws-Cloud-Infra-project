# Inputs. Change values in terraform.tfvars, not here.

variable "project" {
  description = "Name prefix for every resource"
  type        = string
  default     = "minibank"
}

variable "region" {
  description = "AWS region to build in"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "Address range for the whole VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnets, one per AZ (web tier)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnets, one per AZ (database tier, no internet route)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 size for the web server"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS size"
  type        = string
  default     = "db.t3.micro"
}

variable "budget_email" {
  description = "Email that receives the budget alerts"
  type        = string
}

variable "budget_limit_usd" {
  description = "Monthly budget limit in USD"
  type        = string
  default     = "5"
}
