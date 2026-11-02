# S3 bucket for app assets: private, encrypted, versioned.
# Bucket names are global across all AWS customers, so we add a random suffix.

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "assets" {
  bucket        = "${var.project}-assets-${random_id.suffix.hex}"
  force_destroy = true # lab only: lets `terraform destroy` delete a non-empty bucket
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# A test file, so you can prove the EC2 role can read the bucket.
resource "aws_s3_object" "welcome" {
  bucket       = aws_s3_bucket.assets.id
  key          = "welcome.txt"
  content      = "MiniBank asset read via IAM role - no access keys on the server."
  content_type = "text/plain"
}
