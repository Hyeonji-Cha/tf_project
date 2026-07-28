# 3. 보안그룹생성 선언 - EC2전입 하는데 인바운드 포트/IP, 아웃바운드 포트/IP -> 접근 제한!
resource "aws_security_group" "DE-AI-18-IaC-TF-GROUP-CHA" {
  name        = "terraform-18-sg"
  description = "de-ai-18 security group"
  #보안그룹은 vpc종속되어 구성됨
  #id->'리소스명-해시값'으로 구성
  vpc_id = aws_vpc.company-vpc-cha.id
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
  subnet_id     = aws_subnet.public.id
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
  # <<-EOF .. EOF : 여러줄 문자열을 한번에 스크립트나 파일로 넘겨주는 형식(Here-Document)
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y ec2-instance-connect
  EOF

}


# 5. Elastic IP 
resource "aws_eip" "DE-AI-18-IaC-TF-EIP" {
  # EC2 인스턴스 
  instance = aws_instance.DE-AI-18-IaC-TF.id
  # 네트워크
  domain = "vpc"
  tags = {
    Name = "DE-AI-18-IaC-TF-EIP"
  }
}