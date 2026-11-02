# Terraform + providers. NEW in Phase 2: state is stored in S3, not on your laptop.

terraform {
  required_version = ">= 1.11.0"

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

  # Empty on purpose ("partial configuration"): the real values come from
  # backend.hcl, which the bootstrap step generated.
  #   terraform init "-backend-config=backend.hcl"
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Phase     = "2"
      ManagedBy = "Terraform"
    }
  }
}
