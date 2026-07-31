############################################
# 전체 구성상 반복적으로 배치되는 변수값을 구성
############################################
locals {
  #프로젝트명(반복은 아니지만 필수도 아님)-> 상수(고정값 관점)
  project = "DE-AI-cha-18-IaC-3tier-V1"
  common_tags = {
    Project     = locals.project
    Environment = var.environment
    ManageBy    = "Terraform"
  }
  # 서울리전 가용영역 2개(a,c)
  azs = {
    a = "ap-northeast-2a"
    c = "ap-northeast-2c"
  }
  # ALB
  public_subnets = {
    a = "10.0.1.0/24"
    c = "10.0.2.0/24"
  }
  # WEB/WAS
  app_subnets = {
    a = "10.0.11.0/24"
    c = "10.0.12.0/24"
  }
  # RDS
  db_subnets = {
    a = "10.0.21.0/24"
    c = "10.0.22.0/24"
  }
}