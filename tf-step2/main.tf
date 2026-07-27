# 1. 현재 리전의 VPC서비스 중 default 정보 조회(data)
#  - 현재 리전의 vpc 서비스 중 default정보 조회하라 -> data.aws_vpc.default.id 참조
data "aws_vpc" "default" {
  default = true
}

# 2. 기본 VPC의 서비스 정보 조회 하라 (data)
#   n개의 서브넷이 존재하므로 이름 values에 담아라
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 3. 보안그룹생성 선언 - EC2전입 하는데 인바운드 포트/IP, 아웃바운드 포트/IP -> 접근 제한!
resource "aws_security_group" "DE-AI-18-IaC-TF-GROUP-CHA" {
  name        = "terraform-18-sg2"
  description = "de-ai-18 security group"
  #보안그룹은 vpc종속되어 구성됨
  #id->'리소스명-해시값'으로 구성
  vpc_id = data.aws_vpc.default.id
  # 인바운드: 일단 필요한만큼 생성 > 추후 반복문 등 문법 효울적 활용을 통해 구성
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    description = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"] #전세계로 개방
  }

  # 아웃바운드
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"] #전세계로 개방

  }
}


# 아마존 리눅스 AMI의 ID조회
data "aws_ami" "amazon_linux" {
  # 최신설정
  most_recent = true
  # 소유자
  owners = ["amazon"]
  # 필터링
  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  # 프리티어를 사용하려면 필터를 추가해야함 -> EC2에서 인스턴스 유형이 t2/t3 micro등 선택되어야 확정됨
  # 필터 추가
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 4. EC2 생성 선언
resource "aws_instance" "DE-AI-18-IaC-TF" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = data.aws_subnets.default.ids[0] #a,b,c,d중 첫번째 선택
  vpc_security_group_ids = [
    aws_security_group.DE-AI-18-IaC-TF-GROUP-CHA.id
  ]

  # 스토리지 생략
  # 고급 설정 생략
  # 태그
  tags = {
    Name = "DE-AI-18-ap2-IaC-TF-EC2"
  }
  #IP는 임시로 자동할당 (현재 EIP사용 X)
  # TODO: 동일스펙으로 2개 생성
  count = 2
}

# 5. Elastic IP 
# resource "aws_eip" "DE-AI-18-IaC-TF-EIP" {
#   # 동일 스펙으로 2개 생성
#   count = 2
#   # EC2 인스턴스 
#   instance = aws_instance.DE-AI-18-IaC-TF[ count.index ].id
#   # 네트워크
#   domain = "vpc"
# }