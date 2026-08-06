# 생성된 정보를 기반으로 리소스 이름, ID, ARN 등
# 동적으로 만들어진 값을 출력
#
# Kubernetes Manifest 등의 구성 정보를
# 동적으로 설정할 때 필요한 값으로 활용


# ─────────────────────────────────────────────
# EKS 정보
# ─────────────────────────────────────────────

# AWS 리전
output "aws_region" {
  value = var.aws_region
}

# EKS 클러스터 이름
output "cluster_name" {
  value = aws_eks_cluster.main.name
}

# EKS 클러스터 API Endpoint
# kubectl과 AWS CLI가 클러스터 API Server에 접근할 때 사용하는 주소
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

# EKS 클러스터 보안 그룹 ID
# EKS 클러스터 생성 과정에서 동적으로 생성된 보안 그룹
output "cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# EKS Auto Mode Node Role의 ARN
output "auto_mode_node_role_arn" {
  value = aws_iam_role.eks_auto_node.arn
}

# kubectl 연결 설정에 사용할 명령
# 로컬 PC에서 kubectl CLI를 이용해 Kubernetes API Server와 통신하려면
# AWS 리전과 EKS 클러스터 정보를 kubeconfig에 등록해야 함
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}


# ─────────────────────────────────────────────
# VPC 및 Subnet 정보
# ─────────────────────────────────────────────

# VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Public Subnet ID 목록
output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

# Application Subnet ID 목록
output "app_subnet_ids" {
  value = values(aws_subnet.app)[*].id
}

# DB Subnet ID 목록
output "db_subnet_ids" {
  value = values(aws_subnet.db)[*].id
}


# ─────────────────────────────────────────────
# ECR 정보
# ─────────────────────────────────────────────

# Web 이미지 저장소 URL
output "web_ecr_repository_url" {
  value = aws_ecr_repository.web.repository_url
}

# WAS 이미지 저장소 URL
output "was_ecr_repository_url" {
  value = aws_ecr_repository.was.repository_url
}


# ─────────────────────────────────────────────
# RDS 정보
# ─────────────────────────────────────────────

# RDS에 접근할 때 사용하는 Endpoint
# 애플리케이션의 DB Host 값으로 사용
output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

# RDS MySQL 포트
output "rds_port" {
  value = aws_db_instance.mysql.port
}

# RDS 생성 시 구성한 초기 DB 이름
output "rds_db_name" {
  value = var.db_name
}

# 실제 비밀번호가 아니라 AWS Secrets Manager Secret의 ARN을 출력
# 비밀번호에 접근할 때 사용할 Secret 위치 정보
# sensitive = true로 설정하여 일반 Terraform 출력에서 숨김 처리
output "rds_master_secret_arn" {
  value     = aws_db_instance.mysql.master_user_secret[0].secret_arn
  sensitive = true
}