# AWS 리전, 모든 리소스에 공통으로 사용할 태그 설정
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
