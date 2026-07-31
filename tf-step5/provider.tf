terraform {
  required_version = ">=1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}
provider "aws" {
  region = var.region
  # 기본태그 -> 리소스에 기본 반영됨
  default_tags {
    tags = local.common_tags
  }
}
