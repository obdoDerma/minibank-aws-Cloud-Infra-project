# Terraform + provider versions, and the AWS provider settings.
# Works with your installed Terraform 1.11.x.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Phase 1 keeps state locally (terraform.tfstate in this folder).
  # Phase 2 lesson: move it to an S3 backend.
}

provider "aws" {
  region = var.region
  # Credentials come from `aws configure` - never put keys in these files.

  # Every resource gets these tags automatically (easy to find + cost tracking).
  default_tags {
    tags = {
      Project   = var.project
      Phase     = "1"
      ManagedBy = "Terraform"
    }
  }
}
