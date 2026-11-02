# EC2 WEB SERVER + its IAM role.
# The role gives the server permissions WITHOUT storing any keys on it:
#   - SSM: lets you open a shell from the CLI (no SSH, no port 22, no key pair)
#   - S3 read: only the assets bucket (least privilege)

resource "aws_iam_role" "web" {
  name = "${var.project}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_read" {
  name = "${var.project}-s3-read-assets"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.assets.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}

# Latest Amazon Linux 2023 image, looked up at plan time (no hard-coded AMI ID).
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name
  # No key_name on purpose: access is via SSM Session Manager only.

  metadata_options {
    http_tokens = "required" # IMDSv2 only - blocks a common credential-theft attack
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx mariadb105
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    cat > /usr/share/nginx/html/index.html <<HTML
    <html><head><title>MiniBank</title></head>
    <body style="font-family:Arial;background:#0b1f33;color:#fff;text-align:center;padding-top:80px">
    <h1>MiniBank - Phase 1</h1>
    <p>Served from EC2 in $AZ, built by Terraform.</p>
    </body></html>
    HTML
    systemctl enable --now nginx
  EOF

  tags = { Name = "${var.project}-web-1" }
}
