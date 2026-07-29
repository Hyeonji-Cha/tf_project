############################################
# Security Group Rules (반복관련)
############################################
locals {
  security_groups = {
    web = {
      ingress = {
        ssh = {
          port        = 22,
          cidr_blocks = ["0.0.0.0/0"]
        }
        http = {
          port        = 80,
          cidr_blocks = ["0.0.0.0/0"]
        }
      }

    }
    was = {
      ingress = {
        ssh = {
          port        = 22,
          cidr_blocks = ["0.0.0.0/0"]
        }
        # 오직 web->was로만 접근해야함
        # tcp = {
        #     port = 8000,
        #     cidr_blocks = ["0.0.0.0/0"]
        # }
      }

    }
    db = {
      ingress = {
        ssh = {
          port        = 22,
          cidr_blocks = ["0.0.0.0/0"]
        }
        #오직 was->db로만 접근해야함
        # tcp = {
        #     port = 3306,
        #     cidr_blocks = ["0.0.0.0/0"]
        # }
      }

    }

  }
}
############################################
# Security Groups 생성 선언
############################################
resource "aws_security_group" "sg" {
  # 반복 데이터로 구성된 locals 주입
  for_each    = local.security_groups
  name_prefix = "DE-AI-18-${each.key}-sg"
  description = "${upper(each.key)} Security Group"


  # VPC지정
  vpc_id = aws_vpc.company-vpc-cha.id

  # ingress 동적 생성
  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

  }
  # 아웃바운드 고정
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
 
}