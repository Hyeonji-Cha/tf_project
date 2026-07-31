###############################################
# 퍼블릭 ALB 보안 그룹, SSM사용으로 인해 22 포트 제외
###############################################
resource "aws_security_group" "public_alb" {
  name        = "${local.project}-PUBLIC-ALB-SG"
  description = "Allow internet HTTP traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-PUBLIC-ALB-SG" }
}
resource "aws_security_group" "web" {
  name        = "${local.project}-WEB-SG"
  description = "Allow HTTP only from public ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "HTTP from public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-WEB-SG" }
}
resource "aws_security_group" "internal_alb" {
  name        = "${local.project}-INTERNAL-ALB-SG"
  description = "Allow WAS traffic only from WEB tier"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "WAS request from WEB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-INTERNAL-ALB-SG" }
}
resource "aws_security_group" "was" {
  name        = "${local.project}-WAS-SG"
  description = "Allow application traffic only from internal ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Application traffic from internal ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-WAS-SG" }
}
resource "aws_security_group" "rds" {
  name        = "${local.project}-RDS-SG"
  description = "Allow MySQL only from WAS tier"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "MySQL from WAS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.was.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.project}-RDS-SG" }
}