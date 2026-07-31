# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.project}-VPC"
  }
}
# IGW
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.project}-IGW"
  }

}

# Public subnet(Public ALB, NAT Gateway)
resource "aws_subnet" "public" {
  for_each   = local.public_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  # 키값이 a면 a에 맞는 값들로 구성, c도 동일
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.project}-PUBLIC-${upper(each.key)}"
    Tier = "public"
  }

}

# Private Application Subnets(Web,Was,Interna ALB) 
resource "aws_subnet" "app" {
  for_each                = local.app_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.project}-APP-${upper(each.key)}"
    Tier = "application"
  }
}
# Private DB Subnet (RDS)
resource "aws_subnet" "db" {
  for_each                = local.db_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.project}-DB-${upper(each.key)}"
    Tier = "database"
  }
}

# Public Route Table/associtation
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${local.project}-PUBLIC-RT"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id

}


# Nat Gateway - eip
resource "aws_eip" "nat" {
  for_each = local.azs # a존, c존에 각각 IP 할당
  domain   = "vpc"
  tags = {
    Name = "${local.project}-NAT-EIP-${upper(each.key)}" # A, C
  }
}
resource "aws_nat_gateway" "main" {
  for_each      = local.azs
  allocation_id = aws_eip.nat[each.key].id # ..nat['A'].., ..nat['C']..
  # A존의 퍼블릭 서브넷, C존의 퍼블릭 서브넷 각각 연결
  subnet_id = aws_subnet.public[each.key].id
  tags = {
    Name = "${local.project}-NAT-${upper(each.key)}"
  }
  depends_on = [
    aws_internet_gateway.main
  ]
}

# Private App Route Table/association
resource "aws_route_table" "app" {
  for_each = local.azs
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main[each.key].id
  }
  tags = {
    Name = "${local.project}-APP-RT"
  }
}
resource "aws_route_table_association" "app" {
  for_each       = aws_subnet.app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}
# Private Db Route Table/association
# RDS 서비스 사용 -> 기존 EC2 기반 NAT 구성과 상이함
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.project}-DB-RT"
  }
}
resource "aws_route_table_association" "db" {
  for_each       = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}