variable "region" {
  default = "ap-northeast-2"
}
variable "instance_type" {
  default = "t3.micro"
}
variable "key_name" {
  default = "DE-AI-25-TEST"
}
# 리전, 인스턴유형, 키이름 변수로 지정 -> 다른 tf에서 사용 가능