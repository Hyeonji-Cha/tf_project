############################################
# RDS Subnet Group - 서로 다른 AZ의 DB 서브넷 사용
############################################
resource "aws_db_subnet_group" "main" {
  name = "de-ai-25-db-subnet-group"
  # a 존, c 존 프라이빗 서브넷 설정
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]

  tags = { Name = "${local.project}-DB-SUBNET-GROUP" }
}

############################################
# RDS MySQL Multi-AZ
# manage_master_user_password=true:
# 비밀번호를 코드에 저장하지 않고 AWS Secrets Manager가 관리
############################################
resource "aws_db_instance" "mysql" {
  identifier = "de-ai-25-mysql-v1"

  engine         = "mysql"
  instance_class = var.db_instance_class

  # 기본 저장 공간 20GB
  allocated_storage = 20
  # 최대 100GB 증가 가능 -> 필요에 따라 증가만됨
  max_allocated_storage = 100
  # 범용 스토리지 
  storage_type = "gp3"
  # 스냅샷 암호화 설정
  storage_encrypted = true

  # 초기 디비명
  db_name = var.db_name
  # 초기 사용자명
  username = var.db_username
  # 관리자 비번은 AWS Secrets Manager 사용하도록 -> 유료
  manage_master_user_password = true

  # AZ - a : primary Mysql
  # AZ - c : standby Mysql (장애시 대응용)
  # 장애 대응, 오류 발생시 복제본 생성 서비스 유지
  multi_az = true
  # 퍼블릭 IP x
  publicly_accessible = false
  # 서브넷 그룹
  db_subnet_group_name = aws_db_subnet_group.main.name
  # VPC 보안 그룹
  vpc_security_group_ids = [aws_security_group.rds.id]
  # 7일간 보관
  backup_retention_period = 7
  # 백업 수행 시간 => UTC 시간기준, 한국시간 +9시간
  backup_window = "18:00-19:00"
  # RDS 패치 시간 => UTC 시간기준
  maintenance_window = "sun:19:00-sun:20:00"

  # 삭제 방지 기능 않함(운영시 유지)
  deletion_protection = false
  # 삭제시 최종 스냅샷 운영 X, 실습 O
  skip_final_snapshot = true
  # rds 변경 사항 => 즉시 반영(유지보수 -> aws)
  apply_immediately = true

  tags = { Name = "${local.project}-MYSQL" }
}