###################################
# web ec2용 -> launch template 요소(ASG 내에서 사용)를 사용하여 생성됨
###################################
resource "aws_launch_template" "web" {
  name_prefix   = "${local.project}-WEB-" # 증감이 수시로 발생해도 중복 x
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  # SSM 접속을 위해 프로파링 설정 -> iam.tf 구성
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }
  # 보안 그룹 지정
  vpc_security_group_ids = [aws_security_group.web.id]
  # 서버 구성후 초기 작업 -> 쉘스크립트를 읽어서 => base64 인코딩처리 => 실행되게 구성
  user_data = base64encode(templatefile("${path.module}/userdata-web.sh.tftpl", {
    # WEB -> proxy -> Internal ALB (이 리소스의 IP 혹은 dns 알아야 전달)
    # 해당 값을 가져가서 nginx conf 파일을 완성함
    internal_alb_dns = aws_lb.internal.dns_name
  }))
  # 태그
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.project}-WEB"
      Tier = "web"
    })
  }
  # 삭제전 생성 -> ec2 수 유지에 대한 기준
  lifecycle {
    create_before_destroy = true
  }

}

###################################
# was ec2용 -> launch template 요소(ASG 내에서 사용)를 사용하여 생성됨
###################################
resource "aws_launch_template" "was" {
  name_prefix   = "${local.project}-WAS-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }
  vpc_security_group_ids = [aws_security_group.was.id]
  user_data = base64encode(templatefile("${path.module}/userdata-was.sh.tftpl", {
    # rds 세팅값 설정
    db_host = aws_db_instance.mysql.address
    db_port = aws_db_instance.mysql.port
    db_name = var.db_name
    db_user = var.db_username
  }))
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.project}-WAS"
      Tier = "was"
    })
  }
  lifecycle {
    create_before_destroy = true
  }
}