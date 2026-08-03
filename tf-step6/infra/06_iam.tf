##############################################################
# EC2가 SSM Session Manager를 사용 할수 있도록 IAM Role 정의 적용 
# -> 서브넷의 유형에 상관없이 접속가능, pem 필요 x
##############################################################
# 1. EC2가 IAM 역활을 맡을 수 있도록 정책 조회(data)
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    # 서비스명 ec2 조회 조건 지정
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
# 2. role 생성
resource "aws_iam_role" "ec2_ssm" {
  # 프로젝트명을 role에 반영하여 구분할수 있게 처리
  # 역활에 policy(정책)을 반영
  name               = "${var.project_name}-EC2-SSM-Role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
# 3. AmazonSSMManagedInstanceCore(AWS 관리형 정책)에 role 연결
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# 4. EC2 구성시 적용할 IAM 인스턴스 프로필 생성 -> Launch_template에서 ec2 구성할때 사용
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project_name}-EC2-SSM-Profile"
  role = aws_iam_role.ec2_ssm.name
}