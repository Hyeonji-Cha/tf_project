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
  tags = {
    Name = "DE-AI-18-${each.key}-sg"
  }


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

############################################
# Web -> Was 룰 적용, 포트 8000 오픈, 룰생성 선언
############################################
resource "aws_security_group_rule" "web-to-was" {
  type = "ingress"
  # 소스(web) 보안 그룸
  source_security_group_id = aws_security_group.sg["web"].id
  # 타겟(was) 보안 그룹
  security_group_id = aws_security_group.sg["was"].id
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
}

############################################
# was -> DB 룰 적용, 포트 3306 오픈
############################################
resource "aws_security_group_rule" "was-to-to" {
  type = "ingress"
  # 소스(Was) 보안 그룸
  source_security_group_id = aws_security_group.sg["was"].id
  # 타겟(Db) 보안 그룹
  security_group_id = aws_security_group.sg["db"].id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"

}