# 1. 현재 리전의 VPC서비스 중 default 정보 조회(data)
#  - 현재 리전의 vpc 서비스 중 default정보 조회하라 -> data.aws_vpc.default.id 참조
data "aws_vpc" "default" {
  default = true
}

# 2. 기본 VPC의 서비스 정보 조회 하라 (data)
#   n개의 서브넷이 존재하므로 이름 values에 담아라
data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}