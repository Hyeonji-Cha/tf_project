# 반복된 내용 locals 구성 (반복등장/값이 상이한 것: 서브넷, 보안그룹)
locals {
  servers = {
    web = {
      subnet = aws_subnet.public.id
      sg     = aws_security_group.sg["web"].id

    }
    was = {
      subnet = aws_subnet.private.id
      sg     = aws_security_group.sg["was"].id

    }

    db = {
      subnet = aws_subnet.private.id
      sg     = aws_security_group.sg["db"].id

    }
  }
}

# ami 조회
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
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# aws_instance생성 선언 -> 반복
resource "aws_instance" "server" {
  for_each      = local.servers
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = each.value.subnet
  key_name      = var.key_name
  vpc_security_group_ids = [
    each.value.sg
  ]
  tags = {
    Name = "DE-AI-18-ap2-${upper(each.key)}"
  }
  user_data = <<-EOF
        #!/bin/bash
        dnf install -y ec2-instance-connect
    EOF
}



# 오직 web용 ec2와 EIP 생성 선언
# resource "aws_eip" "DE-AI-18-IaC-TF-EIP" {
#   # EC2 인스턴스 
#   instance = aws_instance.server["web"].id
#   # 네트워크
#   domain = "vpc"
#   tags = {
#     Name = "DE-AI-18-web-EIP"
#   }
# }