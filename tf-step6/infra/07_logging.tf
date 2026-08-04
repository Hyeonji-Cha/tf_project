# AWS CloudWatch 서비스 관련 설정(로그 저장, 관리, 조회 등을 수행하는 서비스)
# 쿠버네티스 컨트롤 플레인의 로그를 CloudWatch의 특정 경로에 저장하고 7일간 보관
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7 # 7일만 보관

  tags = {
    Name = "${local.cluster_name}-cluster-log"
  }
}