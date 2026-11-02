# NETWORK - 3 tiers x 2 AZs = 6 subnets.
#   public  : load balancer only (route to internet gateway)
#   app     : web servers (NO internet route; S3 reachable via a free gateway endpoint)
#   db      : database (local VPC route only)
# NEW vs Phase 1: app tier is private, and an S3 gateway endpoint replaces a NAT gateway.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  sfx = ["a", "b"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# ---------- Public tier (ALB) ----------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # nothing here needs auto public IPs; the ALB manages its own
  tags                    = { Name = "${var.project}-public-${local.sfx[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------- App tier (private web servers) ----------
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project}-app-${local.sfx[count.index]}" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  # No 0.0.0.0/0 route: servers cannot reach the internet.
  # The S3 endpoint below adds a route to S3 only.
  tags = { Name = "${var.project}-app-rt" }
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# FREE gateway endpoint: private route to S3. Amazon Linux 2023 package repos are
# hosted on S3, so `dnf install` works without a NAT gateway (~$33/month saved).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]
  tags              = { Name = "${var.project}-s3-endpoint" }
}

# ---------- DB tier ----------
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project}-db-${local.sfx[count.index]}" }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-db-rt" }
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ---------- Optional: SSM endpoints (shell into private servers) ----------
# Interface endpoints cost money per hour, so they are OFF by default.
# Placed in ONE subnet only to halve the cost (servers in AZ b still reach it).
resource "aws_vpc_endpoint" "ssm" {
  for_each            = var.enable_ssm_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.app[0].id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.project}-${each.key}-endpoint" }
}
