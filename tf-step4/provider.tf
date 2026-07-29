terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}
provider "aws" {
  #region = "ap-northeast-2"
  # 변수 대체
  region = var.region

}
# 공급자에 대한 설명
# aws provider에 대한 설명, 서울 리전 지정
# 변수가 없으므로 하드코딩 -> 리전 파트