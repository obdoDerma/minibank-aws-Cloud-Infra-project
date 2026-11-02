# BOOTSTRAP: run ONCE. Creates the S3 bucket that stores Terraform state for Phase 2+.
# Why separate? The state bucket must exist BEFORE the project that uses it,
# and it must survive `terraform destroy` of the project. Cost: a few cents/month.
#
# It also writes ../phase2/backend.hcl so Phase 2 knows where its state lives.

terraform {
  required_version = ">= 1.11.0" # needed for S3 native state locking (use_lockfile)

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "minibank", Purpose = "terraform-state", ManagedBy = "Terraform" }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "minibank-tfstate-${random_id.suffix.hex}"
  # true = lab convenience so you can delete it at project end.
  # In a real company this is false + prevent_destroy.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled" # every state change is kept: you can roll back a bad state
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Writes the backend settings file for Phase 2.
resource "local_file" "phase2_backend" {
  filename = "${path.module}/../phase2/backend.hcl"
  content  = <<-EOT
    bucket       = "${aws_s3_bucket.state.bucket}"
    key          = "phase2/terraform.tfstate"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}
