# ────────────────────────────────────────────────
# EKS Cluster Role 생성
# Auto Mode에서 컴퓨팅, 네트워킹, LB, 스토리지등 관리할 권한 부여
# 특정 서비스의 정책 -> 특정 역할에 부여 -> 해당 역할을 특정 사용자에게 부여 -> 특정 사용자는
# 특정 서비스의 관리/조작/등 행위(액션)을 수행수 있다 => EKS에 관련된 정책->역활->사용자에게반영
# ────────────────────────────────────────────────

# ────────────────────────────────────────────────
# 1. EKS Cluster 정책 획득
# ────────────────────────────────────────────────
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    # EKS 서비스에서만 해당 역할을 사용할 수 있게 제한
    principals {
      type        = "Service"
      # IAM ROLE은 EKS가 사용할 수 있다.
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
# ────────────────────────────────────────────────
# 2. EKS Cluster Role 생성
# ────────────────────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  # 특정 계정(구분용) 위한 롤 구성
  name = "${local.cluster_name}-cluster-role"
  # 역활에 정책 => 위에서 구성한 내용 조회하여 반영
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}
# ────────────────────────────────────────────────
# 3. EKS Cluster aws 관리형 정책 획득 -> 고정값 사전 상수로 나열 -> locals
#    컴퓨팅, 클러스터, 블록스토리지, 로드밸런스, 네트워킹 정책 -> 나열
# ────────────────────────────────────────────────
locals {
  # 필요한 정책들 나열하여 구성
  # arn(amazon resource name) 리소스의 고유 식별 이름
  # arn:파티션:서비스명:리소스가속한리전:서비스계정ID:리소스명(여기서는정책)
  eks_auto_cluster_policies = {
    cluster        = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    compute        = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
    block_storage  = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2"
    load_balancing = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    networking     = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  }
}
# ────────────────────────────────────────────────
# 4. EKS 관리형 정책을 반영할 Role에 정책 부여
# ────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = local.eks_auto_cluster_policies

  # 위에서 나열한 정책을 위에서 만든 ROLE에 반복적으로 부여
  role       = aws_iam_role.eks_cluster.name
  policy_arn = each.value
}
# 결론 : aws_iam_role 역활 생성 완료 (EKS 서비스 관리를 위한 정책들 역활에 모두 부여함)


# ────────────────────────────────────────────────
# EKS Auto Mode Node Role 생성
# 자동으로 생성되는 ec2 node가 EKS 참여, ECR pull에 사용되는 정책을 가진 역활
# ────────────────────────────────────────────────
# ────────────────────────────────────────────────
# 1. ec2 정책 획득
# ────────────────────────────────────────────────
data "aws_iam_policy_document" "eks_auto_node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
# ────────────────────────────────────────────────
# 2. EKS Auto Mode `Node Role` 생성
# ────────────────────────────────────────────────
resource "aws_iam_role" "eks_auto_node" {
  name               = "${local.cluster_name}-auto-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_auto_node_assume.json
}
# ────────────────────────────────────────────────
# 3. 워커 노드 정책, ECR PULL 정책 명시적 나열
# ────────────────────────────────────────────────
locals {
  eks_auto_node_policies = {
    worker = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
    ecr    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }
}
# ────────────────────────────────────────────────
# 4. 기본 ec2 정책 + 3번 사항의 2개 정책을 새로 생성한 Node Role에 추가
# ────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "eks_auto_node" {
  for_each = local.eks_auto_node_policies

  role       = aws_iam_role.eks_auto_node.name
  policy_arn = each.value
}