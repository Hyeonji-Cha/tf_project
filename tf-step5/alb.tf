resource "aws_lb" "public" {
  name               = "de-ai-cha-18-public-alb"
  internal           = false
  load_balancer_type = "application"
  #보안그룹 - 퍼블릭 ALB
  security_groups    = [aws_security_group.public_alb.id]
  # 퍼블릭 서브넷 가용영역별 2개 각각 id를 추출
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  tags = { Name = "${local.project}-PUBLIC-ALB" }
}
# ALB가 주기적으로 대상 EC2의 상태를 체크하는 설정(헬스체크 등)
resource "aws_lb_target_group" "web" {
  name        = "de-ai-cha-18-web-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
  health_check {
    enabled             = true # 헬스 체크 사용 여부
    path                = "/health" # 체크하는 URL값(경로)
    protocol            = "HTTP"
    matcher             = "200" # 정상 응답 코드 값
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2 # 연속으로 N번 성공해야 정상 상태로 인지
    unhealthy_threshold = 2
  }
  tags = { Name = "${local.project}-WEB-TG" }
}
resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
resource "aws_lb" "internal" {
  name               = "de-ai-cha-18-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = [for subnet in aws_subnet.app : subnet.id]
  tags = { Name = "${local.project}-INTERNAL-ALB" }
}
resource "aws_lb_target_group" "was" {
  name        = "de-ai-cha-18-was-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${local.project}-WAS-TG" }
}
resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 8000
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.was.arn
  }
}