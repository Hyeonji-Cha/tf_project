resource "aws_vpc" "company-cha" {
    #CIDR 블록 크기는 /16에서 /28 -> AWS제약사항
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name ="company-vpc-cha"
  }
}