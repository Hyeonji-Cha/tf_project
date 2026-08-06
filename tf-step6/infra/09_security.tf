# ────────────────────────────────────────────────
# RDS 보안 그룹
# ────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  # 보안 그룹 이름
  name = "${local.cluster_name}-rds-sg"

  # EKS 클러스터에서만 RDS에 접근 가능
  description = "MySQL access only from the EKS cluster security group"

  # 보안 그룹을 생성할 VPC
  vpc_id = aws_vpc.main.id

  # 인바운드 규칙
  ingress {
    description = "MySQL access from EKS Auto Mode Nodes and WAS Pods"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"

    # EKS Auto Mode와 VPC 설정에 따라 자동 생성된
    # EKS 클러스터 보안 그룹에서만 MySQL 접근 허용
    security_groups = [
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }

  # 아웃바운드 규칙
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 태그
  tags = {
    Name = "${local.cluster_name}-rds-sg"
  }
}