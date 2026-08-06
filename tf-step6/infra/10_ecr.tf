# ────────────────────────────────────────────────
# Web ECR 저장소
# ────────────────────────────────────────────────
resource "aws_ecr_repository" "web" {
  # 저장소 이름 예시: "de-ai-18-cha-eks-auto-dev-cha/web"
  name = "${local.cluster_name}/web"

  # 이미지 태그 설정
  # 같은 이미지 태그를 다시 Push할 수 있어 실습 및 개발 환경에서 유용
  # 운영 환경에서는 버전 번호, Commit ID 등을 활용하여 이미지를 구분하는 것이 안전
  image_tag_mutability = "MUTABLE"

  # Terraform destroy 실행 시 이미지가 남아 있어도 저장소와 함께 삭제할지 설정
  # 운영 환경에서는 보존 정책에 따라 다르게 설정할 수 있음
  force_delete = true

  # 이미지를 Push할 때 알려진 취약점을 자동으로 검사
  image_scanning_configuration {
    scan_on_push = true
  }

  # 태그
  tags = {
    Name = "${local.cluster_name}-ecr-web-repo"
  }
}

# ────────────────────────────────────────────────
# WAS ECR 저장소
# ────────────────────────────────────────────────
resource "aws_ecr_repository" "was" {
  # 저장소 이름 예시: "de-ai-18-cha-eks-auto-dev-cha/was"
  name = "${local.cluster_name}/was"

  # 같은 이미지 태그를 다시 Push할 수 있도록 설정
  image_tag_mutability = "MUTABLE"

  # Terraform destroy 실행 시 이미지가 남아 있어도 저장소와 함께 삭제
  force_delete = true

  # 이미지를 Push할 때 알려진 취약점을 자동으로 검사
  image_scanning_configuration {
    scan_on_push = true
  }

  # 태그
  tags = {
    Name = "${local.cluster_name}-ecr-was-repo"
  }
}

# ────────────────────────────────────────────────
# ECR 저장소 관련 Lifecycle Policy
# ────────────────────────────────────────────────

# 1. 위에서 생성한 ECR 저장소를 하나의 묶음으로 구성
locals {
  ecr_repositories = {
    web = aws_ecr_repository.web.name
    was = aws_ecr_repository.was.name
  }
}

# 2. 태그 유무와 관계없이 최근 Push된 이미지 10개만 유지
# 오래된 이미지는 만료 처리
# CI/CD 적용 이후 동작을 확인하며, 회사 상황에 따라 정책이 달라질 수 있음
resource "aws_ecr_lifecycle_policy" "main" {
  # 저장소 이름을 기준으로 반복 적용
  for_each = local.ecr_repositories

  # Lifecycle Policy를 적용할 저장소 이름
  repository = each.value

  # HCL로 작성한 정책을 ECR이 요구하는 JSON 형식으로 변환
  policy = jsonencode({
    rules = [
      {
        # Lifecycle 규칙 실행 우선순위
        rulePriority = 1

        # 규칙 설명
        description = "최신 이미지 10개만 유지"

        # 정책 적용 대상 선택
        selection = {
          # 태그 존재 여부와 관계없이 모든 이미지 대상
          tagStatus = "any"

          # 유지할 이미지 개수
          countNumber = 10

          # 이미지 개수가 기준을 초과하면 오래된 이미지부터 만료 처리
          countType = "imageCountMoreThan"
        }

        # 만료 처리 액션
        action = {
          # 오래된 이미지를 만료 처리하여 삭제
          type = "expire"
        }
      }
    ]
  })
}