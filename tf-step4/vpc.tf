resource "aws_vpc" "company-vpc-cha" {
  #CIDR 블록 크기는 /16에서 /28 -> AWS제약사항
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "company-vpc-cha"
  }
}

# 서브넷(public)
resource "aws_subnet" "public" {
  # 암묵적 의존성: 서브넷 구성을 위해서는 반드시 vpc가 먼저 생성되어야 함
  vpc_id = aws_vpc.company-vpc-cha.id
  # CIDR 가용영역 설정, VPC보다 작게, 24(3자리 고정)
  cidr_block = "10.0.1.0/24"
  # 리전마다 가용영역이  a,b,c,d 제한 -> 데이터 센터 동수 
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "DE-AI-18-public-subnet-cha"
  }

}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "company" {
  vpc_id = aws_vpc.company-vpc-cha.id
  tags = {
    Name = "DE-AI-18-cha-igw"
  }
}

# 라우트 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.company-vpc-cha.id
  route {
    # 모든 IP대역 -> IGW 전달(연결)
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.company.id
  }
  tags = {
    Name = "DE-AI-18-cha-public-rt"
  }
}

# 최종연결(공개용 서브넷 -> 공개용 라우트 테이블)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id

}

# private 서브넷 구성
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.company-vpc-cha.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "DE-AI-18-private-subnet"
  }
}

# 라우트 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.company-vpc-cha.id
  tags = {
    Name = "DE-AI-18-cha-private-rt"
  }
}

# 최종연결 (프라이빗 서브넷 -> 프라이빗전용 라우트테이블)
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

############################################
# NAT Gateway 작업
############################################
# 1.eip
resource "aws_eip" "DE-AI-18-IaC-TF-EIP-NAT" {
  # EC2 인스턴스 
  domain = "vpc"
  tags = {
    Name = "DE-AI-18-web-EIP-NAT"
  }
}

# 2. NAT Gateway
resource "aws_nat_gateway" "DE-AI-NAT-GW" {
  allocation_id = aws_eip.DE-AI-18-IaC-TF-EIP-NAT.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "DE-AI-NAT-GW-Cha"
  }
  # 명시적 의존성 표기
  depends_on = [
    aws_internet_gateway.company
  ]

}

# 3. 라우트 테이블에 라우트 설정(nat와 연결)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.DE-AI-NAT-GW.id
}