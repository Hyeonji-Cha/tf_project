############################################
# tf 전체에서 사용할 변수 7개 정의
############################################
variable "region" {
  description = "AWS리전"
  type        = string
  default     = "ap-northeast-2"
}
variable "environment" {
  description = "구동 환경"
  type        = string
  default     = "dev"
}
variable "instance_type" {
  description = "web, was EC2인스턴스 유형"
  type        = string
  default     = "t3.micro"
}
variable "web_desired_capacity" {
  description = "web asg 기본 인스턴스 수"
  type        = number
  default     = 2
}
variable "was_desired_capacity" {
  description = "was asg 기본 인스턴스 수"
  type        = number
  default     = 2
}
variable "db_instance_class" {
  description = "DB 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}
variable "db_name" {
  description = "초기 생성 데이터베이스 이름"
  type        = string
  default     = "appdb"
}
variable "user_name" {
  description = "RDS관리자 이름"
  type        = string
  default     = "adminuser"
}