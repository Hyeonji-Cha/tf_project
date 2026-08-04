# ────────────────────────────────────────────────
# EKS Auto Mode 클러스터 생성 선언
# ────────────────────────────────────────────────

# 쿠버네티스 컨트로 플레인 생성, EKS Auto Mode 기능 활성화 
resource "aws_eks_cluster" "main" {
  # eks 클러스터 이름
  name = local.cluster_name

  # 버전 (1.35)
  version = var.kubernetes_version

  # EKS Control plane이 AWS 리소스 관리할대 IAM role
  role_arn = aws_iam_role.eks_cluster.arn

  # Auto Mode(자동 직접 관리) 이므로 컨트롤 플레인에 필요한 기능등 별도로 addon 하지 않음
  bootstrap_self_managed_addons = false

  # EKS 접근 권한 관리 방식
  access_config {
    authentication_mode = "API" # EKS Access Entry API 사용
    # 테라폼으로 클러스터를 생성한 IAM 사용자 또는 Role[v]에 최초 클러스터 관리자 권한 부여
    bootstrap_cluster_creator_admin_permissions = true
  }

  # EKS Auto Mode Compute 설정
  compute_config {
    # auto mode의 ec2 노드 자동 관리 기능 활성화
    enabled = true

    # 노드 구성 => 노드풀에서 가져와서 구성
    node_pools = [
      "general-purpose", # web, was등 pod 실행하는 용도의 node
      "system"            # 중요 시스템 pod용
    ]

    # auto mode가 node_pools에서 타입에 맞춰 용도에 맞는 node 생성(ec2만듬) -> IAM Role 적용
    node_role_arn = aws_iam_role.eks_auto_node.arn # iam.tf에서 생성한 role 부여
  }

  # 쿠버네티스 네트워크 설정
  kubernetes_network_config {
    # 쿠버네티스 클러스터  내부용으로 사용되는 가상 IP 대역 부분은
    # 기존 vpc, pod, node의 사용하는 CIDR과 겹치면 x
    # 다른 범위로 임시 설정 (다른 구간 지정)
    service_ipv4_cidr = "172.20.0.0/16"

    # 로드 밸런스 서비스 감지 설정
    elastic_load_balancing {
      enabled = true
    }
  }

  # 쿠버네티스 영구 스토리지 설정
  storage_config {
    # 볼륨 생성하여 pod에 연결 => auto mode의 블록 스토리지 관리 기능 활성화
    block_storage {
      enabled = true
    }
  }

  # EKS가 사용하는 VPC, API endpoing  설정
  vpc_config {
    # private 서브넷에 배치
    subnet_ids = values(aws_subnet.app)[*].id # 가용영역별 존재하는 서브넷 모두세팅(ids)
    # VPC 내부에서 private eks api 엔드포인트 접속 허용
    endpoint_private_access = true
    # 로컬 PC에서 public eks api 엔드포인트 접근 허용 (cli등으로 접근)
    endpoint_public_access = true
    # cidr 제약(현재, 어떤 대역이던 접근 OK 구성)
    # public eks API Endpoint (CLI로 접근하여 명령어 전송등 처리 모든 대역 OK)
    public_access_cidrs = var.cluster_endpoint_public_access_cidr
  }

  # 컨트롤 플레인의 로그 -> 컨트롤 플레인(두뇌) -> cloudwatch 로그 전송
  enabled_cluster_log_types = [
    "api",               # API 요청
    "audit",             # 누가 어떤 작업을 수행했는가 기록
    "authenticator",     # AWS IAM 인증 처리        
    "controllerManager", # Deployment, ReplicaSet 제어 > pod 수치/증감
    "scheduler"          # Pod가 어떤 node에 배치되는가 기록
  ]

  # 태그
  tags = {
    Name = local.cluster_name
  }

  # 의존성 -> 아래 리소스들이 구성이 완료되어 있어야 eks 리소스 생성 시작한다
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_auto_node,
    aws_route_table_association.app,
    aws_cloudwatch_log_group.eks
  ]
}


# ────────────────────────────────────────────────
# Metrics Server addon 구성 (CPU 사용량등 => pod증감등 관련 지표 )
# ────────────────────────────────────────────────
# Node, Pod의 현재 CPU, Memory 사용량 수집
# 목적
# 모니터링 : 
#  > kubectl top nodes
#  > kubectl top pods
# pod 확장 -> HPA는  CPU, Memeory 사용량 고려(커스텀 정책(cpu 60% 초과하면 증설하시오)) 증량
# pod 감소 -> ..
# 장기 지표 저장 및 시각화 => 프로메테우스/그라파나 사용 (대시보드 구성) => 관제
resource "aws_eks_addon" "metrics_server" {
  # 매트릭 서버를 에드온할 대상 EKS 클러스터
  cluster_name = aws_eks_cluster.main.name
  # Add-on 이름
  addon_name = "metrics-server"
  # 이미 설정이된 경우 -> 설정 덮어쓰기로 구성
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  # 태그
  tags = {
    Name = "${local.cluster_name}-metrics-server"
  }
}


# ────────────────────────────────────────────────
# IAM Role 부분 추가 등록등 처리 - 추가 관리자 access 엔트리
# ────────────────────────────────────────────────
# var.additional_admin_role_arns에 설정된 계정들도 EKS 클러스터에 접근하도록 관리 주체도 등록
# 현재는 비워 있음 => []
resource "aws_eks_access_entry" "admin" {
  # 등록된 사용자 수 만큼 eks 클러스터 관리자에 등록하기 위해 엔트리 반복 데이터로 배치
  for_each = var.additional_admin_role_arns

  # 대상 eks 클러스터
  cluster_name = aws_eks_cluster.main.name

  # 접근할 role arn
  principal_arn = each.value

  # 타입 : 일반 Iam 사용자, 다른 일반 role에 부여
  type = "STANDARD"
}
# 엔트리에 등록된 IAM Role에 eks 클러스터 관리자 권한을 실제 할당
resource "aws_eks_access_policy_association" "admin" {
  # 대상자(role등) 반복 설정
  for_each = var.additional_admin_role_arns

  # 권한을 적용할 eks 클러스터
  cluster_name = aws_eks_cluster.main.name

  # 접근할 role arn
  principal_arn = each.value

  # 실제 관리자 정책 => AWS에서 사전에 확정한 정책 => arn 방식 표기
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  # 접근 범위
  access_scope {
    # 특정 네임스페이스가 아닌 전체 클러스터에 영향을 미침(전체 권한 적용)
    type = "cluster"
  }

  # 의존성
  depends_on = [aws_eks_access_entry.admin]
}