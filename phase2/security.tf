# SECURITY GROUP CHAIN - each tier only trusts the tier in front of it:
#   internet --80--> alb-sg --80--> app-sg --3306--> db-sg
# Rules reference security groups, not IP ranges, so they keep working when
# Auto Scaling replaces servers with new IPs.

# ---------- Load balancer ----------
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB: HTTP from internet"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Only to app servers on 80"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.app.id
}

# ---------- App servers ----------
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App servers: HTTP only from the ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Out to S3 endpoint, DB, SSM endpoints (no internet route exists anyway)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- Database ----------
resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "DB: MySQL only from app servers"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from app-sg only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.app.id
}

# ---------- SSM interface endpoints (used only if enabled) ----------
resource "aws_security_group" "endpoints" {
  name        = "${var.project}-endpoints-sg"
  description = "HTTPS from app servers to SSM endpoints"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from app-sg"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.app.id
}
