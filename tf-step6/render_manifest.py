#!/usr/bin/env python3
import os
import string
import sys
from pathlib import Path

# 쿠버네티스 동적 정보 3개( 네임스페이스, web/was 이미지 레퍼지토리 주소)
required = ["APP_NAMESPACE", "WEB_IMAGE", "WAS_IMAGE"]
missing = [name for name in required if not os.getenv(name)]
# 해당 정보를 획득 하지 못하면 중단
if missing:
    raise SystemExit(f"Missing environment variables: {', '.join(missing)}")

# 매니페이스 템플릿 파일 경로 획득
template_path = Path(__file__).parent / "k8s" / "app.yaml.tpl"
# 파일 내용 읽음 (템플릿 형태)
template = string.Template(template_path.read_text(encoding="utf-8"))
# 데이터 주입 => 동적 생성 => 출력 스트림 전송
sys.stdout.write(template.substitute(os.environ))