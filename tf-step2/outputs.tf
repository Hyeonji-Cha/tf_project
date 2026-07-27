# EC2 생성시 자동으로 부여되는 IP 
output "public_ip" {
  # TODO: count사용에 따라 [*] 조정
  value = aws_instance.DE-AI-18-IaC-TF[*].public_ip
}

# EC2 인스턴스 ID 출력
output "instance_id" {
  # value = aws_instance.DE-AI-18-IaC-TF.id
  # TODO: count에 따라 출력 방식 변경
  value = [
    # aws_instance.DE-AI-25-IaC-TF 하나씩 꺼내서(instance.id) instance 담는다
    for instance in aws_instance.DE-AI-18-IaC-TF : instance.id
  ]
}
