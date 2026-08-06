# ────────────────────────────────────────────────
# EKS Auto Mode 클러스터 생성 선언
# ────────────────────────────────────────────────

# 쿠버네티스 컨트롤 플레인 생성 및 EKS Auto Mode 기능 활성화
resource "aws_eks_cluster" "main" {
  # EKS 클러스터 이름
  name = local.cluster_name

  # 버전(1.35)
  version = var.kubernetes_version

  # EKS Control Plane이 AWS 리소스를 관리할 때 사용하는 IAM Role
  role_arn = aws_iam_role.eks_cluster.arn

  # Auto Mode가 직접 관리하므로 컨트롤 플레인에 필요한 기능 등을 별도로 Add-on으로 구성하지 않음
  bootstrap_self_managed_addons = false

  # EKS 접근 권한 관리 방식
  access_config {
    authentication_mode = "API" # EKS Access Entry API 사용

    # Terraform으로 클러스터를 생성한 IAM 사용자 또는 Role에 최초 클러스터 관리자 권한 부여
    bootstrap_cluster_creator_admin_permissions = true
  }

  # EKS Auto Mode Compute 설정
  compute_config {
    # Auto Mode의 EC2 Node 자동 관리 기능 활성화
    enabled = true

    # Node 구성: Node Pool에서 가져와서 구성
    node_pools = [
      "general-purpose", # Web, WAS 등의 Pod를 실행하는 용도의 Node
      "system"           # 중요 시스템 Pod용
    ]

    # Auto Mode가 Node Pool의 용도에 맞는 Node를 생성(EC2 생성)하고 IAM Role을 적용
    node_role_arn = aws_iam_role.eks_auto_node.arn # iam.tf에서 생성한 Role 부여
  }

  # 쿠버네티스 네트워크 설정
  kubernetes_network_config {
    # 쿠버네티스 클러스터 내부용으로 사용하는 가상 IP 대역은
    # 기존 VPC, Pod, Node가 사용하는 CIDR과 겹치면 안 됨
    # 다른 범위로 임시 설정
    service_ipv4_cidr = "172.20.0.0/16"

    # 로드 밸런서 서비스 감지 설정
    elastic_load_balancing {
      enabled = true
    }
  }

  # 쿠버네티스 영구 스토리지 설정
  storage_config {
    # 볼륨을 생성하여 Pod에 연결하고, Auto Mode의 블록 스토리지 관리 기능 활성화
    block_storage {
      enabled = true
    }
  }

  # EKS가 사용하는 VPC 및 API Endpoint 설정
  vpc_config {
    # Private Subnet에 배치
    subnet_ids = values(aws_subnet.app)[*].id # 가용 영역별로 존재하는 서브넷 ID를 모두 설정

    # VPC 내부에서 Private EKS API Endpoint 접속 허용
    endpoint_private_access = true

    # 로컬 PC에서 Public EKS API Endpoint 접근 허용(CLI 등으로 접근)
    endpoint_public_access = true

    # CIDR 제약: 현재는 모든 대역에서 접근 가능하도록 구성
    # Public EKS API Endpoint에 CLI로 접근하여 명령어 전송 가능
    public_access_cidrs = var.cluster_endpoint_public_access_cidr
  }

  # 컨트롤 플레인의 로그를 CloudWatch Logs로 전송
  enabled_cluster_log_types = [
    "api",               # API 요청
    "audit",             # 누가 어떤 작업을 수행했는지 기록
    "authenticator",     # AWS IAM 인증 처리
    "controllerManager", # Deployment, ReplicaSet 제어 및 Pod 수 조절
    "scheduler"          # Pod가 어떤 Node에 배치되는지 기록
  ]

  # 태그
  tags = {
    Name = local.cluster_name
  }

  # 의존성: 아래 리소스 구성이 완료된 후 EKS 리소스 생성을 시작
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_auto_node,
    aws_route_table_association.app,
    aws_cloudwatch_log_group.eks
  ]
}


# ────────────────────────────────────────────────
# Metrics Server Add-on 구성
# CPU 사용량 등 Pod 증감과 관련된 지표 수집
# ────────────────────────────────────────────────

# Node와 Pod의 현재 CPU 및 Memory 사용량 수집
# 목적
# 모니터링:
#   kubectl top nodes
#   kubectl top pods
#
# Pod 확장:
# HPA는 CPU와 Memory 사용량을 고려하여
# 커스텀 정책에 따라 Pod 수를 증가시킴
# 예: CPU 사용률이 60%를 초과하면 Pod 증설
#
# Pod 감소:
# 사용량이 감소하면 설정된 정책에 따라 Pod 수를 감소시킴
#
# 장기 지표 저장 및 시각화:
# Prometheus와 Grafana를 사용하여 대시보드 및 관제 환경 구성
resource "aws_eks_addon" "metrics_server" {
  # Metrics Server Add-on을 설치할 대상 EKS 클러스터
  cluster_name = aws_eks_cluster.main.name

  # Add-on 이름
  addon_name = "metrics-server"

  # 이미 설정된 경우 기존 설정을 덮어쓰도록 구성
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # 태그
  tags = {
    Name = "${local.cluster_name}-metrics-server"
  }
}


# ────────────────────────────────────────────────
# IAM Role 추가 등록 처리
# 추가 관리자 Access Entry 구성
# ────────────────────────────────────────────────

# var.additional_admin_role_arns에 설정된 계정도
# EKS 클러스터에 접근할 수 있도록 관리 주체로 등록
# 현재는 비어 있음: []
resource "aws_eks_access_entry" "admin" {
  # 등록된 사용자 수만큼 EKS 클러스터 관리자 Entry를 반복 생성
  for_each = var.additional_admin_role_arns

  # 대상 EKS 클러스터
  cluster_name = aws_eks_cluster.main.name

  # 접근할 Role ARN
  principal_arn = each.value

  # 타입: 일반 IAM 사용자 또는 Role에 적용
  type = "STANDARD"
}


# Entry에 등록된 IAM Role에 EKS 클러스터 관리자 권한을 실제로 할당
resource "aws_eks_access_policy_association" "admin" {
  # 대상 IAM Role 등을 반복 설정
  for_each = var.additional_admin_role_arns

  # 권한을 적용할 EKS 클러스터
  cluster_name = aws_eks_cluster.main.name

  # 접근할 Role ARN
  principal_arn = each.value

  # 실제 관리자 정책
  # AWS에서 사전에 정의한 정책을 ARN 방식으로 표기
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  # 접근 범위
  access_scope {
    # 특정 Namespace가 아닌 전체 클러스터에 권한 적용
    type = "cluster"
  }

  # 의존성
  depends_on = [aws_eks_access_entry.admin]
}