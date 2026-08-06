# ────────────────────────────────────────────────
# RDS DB Subnet Group
# 서로 다른 가용 영역의 DB Subnet 사용
# ────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  # DB Subnet Group 이름
  name = "${local.cluster_name}-db-subnet-group"

  # 서로 다른 가용 영역에 생성된 DB Subnet ID를 모두 등록
  subnet_ids = values(aws_subnet.db)[*].id

  # 태그
  tags = {
    Name = "${local.cluster_name}-db-subnet-group"
  }
}

# ────────────────────────────────────────────────
# RDS MySQL Multi-AZ
#
# manage_master_user_password = true:
# 관리자 비밀번호를 코드에 저장하지 않고
# AWS Secrets Manager에서 생성하고 관리
# ────────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  # RDS 인스턴스 식별자
  identifier = "${local.cluster_name}-mysql"

  # 데이터베이스 엔진 및 버전
  engine         = "mysql"
  engine_version = "8.0"

  # RDS 인스턴스 성능 등급
  instance_class = var.db_instance_class

  # 초기 저장 공간
  allocated_storage = var.db_allocated_storage

  # 스토리지 자동 확장 시 최대 100GB까지 증가 가능
  # 저장 공간은 필요에 따라 증가만 됨
  max_allocated_storage = 100

  # 범용 SSD 스토리지
  storage_type = "gp3"

  # RDS 스토리지 암호화
  storage_encrypted = true

  # 초기 DB 이름
  db_name = var.db_name

  # 초기 관리자 사용자 이름
  username = var.db_username

  # 관리자 비밀번호는 AWS Secrets Manager에서 관리
  manage_master_user_password = true

  # Multi-AZ 구성
  # AZ a: Primary MySQL
  # AZ c: Standby MySQL
  # 장애 발생 시 Standby 인스턴스로 전환하여 서비스 유지
  multi_az = true

  # 퍼블릭 IP를 사용하지 않고 Private Subnet에 배치
  publicly_accessible = false

  # RDS가 사용할 DB Subnet Group
  db_subnet_group_name = aws_db_subnet_group.main.name

  # RDS에 적용할 VPC 보안 그룹
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  # 자동 백업 보관 기간
  backup_retention_period = 7

  # 백업 수행 시간
  # UTC 기준 18:00~19:00, 한국 시간 기준 다음 날 03:00~04:00
  backup_window = "18:00-19:00"

  # RDS 유지보수 및 패치 시간
  # UTC 기준 일요일 19:00~20:00
  # 한국 시간 기준 월요일 04:00~05:00
  maintenance_window = "sun:19:00-sun:20:00"

  # 삭제 방지 기능을 사용하지 않음
  # 운영 환경에서는 true로 설정하여 삭제 방지 기능을 사용할 수 있음
  deletion_protection = false

  # 삭제 시 최종 스냅샷을 생성하지 않음
  # 실습 환경에서는 true, 운영 환경에서는 보존 정책에 따라 설정
  skip_final_snapshot = true

  # RDS 변경 사항을 다음 유지보수 시간까지 기다리지 않고 즉시 반영
  apply_immediately = true

  # 태그
  tags = {
    Name = "${local.cluster_name}-mysql"
  }
}