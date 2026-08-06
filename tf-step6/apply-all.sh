#!/usr/bin/env bash
# (Shebang) 선언 -------------
# 권한 조정(1회성) : chmod +x apply-all.sh
# 스크립트 실행    : ./apply-all.sh

#############################################
# 0. 기본 환경 구성 
#############################################
# -e : 명령이 실패하면 즉시 스크립트를 종료
# -E : 함수나 서브셸에서도 ERR 트랩을 상속 (향후 오류 처리 함수 추가시 대용)
# -u : 정의되지 않은 변수를 사용하면 오류로 처리
# -o pipefail : 파이프라인 중간의 명령이 실패해도 전체 명령을 실패로 처리
set -Eeuo pipefail

# 현재 스크립트(appy-all.sh)가 위치한 디렉터리의 절대경로 획득 (앞 명령 성공시만 뒤 명령 수행)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Terraform 코드가 들어 있는 디렉터리를 지정
INFRA_DIR="${ROOT_DIR}/infra"
# Kubernetes Namespace 이름을 결정 : ${변수:-기본값}
APP_NAMESPACE="${APP_NAMESPACE:-de-ai-25}"
# Docker 이미지 태그를 결정
# WEB_REPO:v3-auto, WAS_REPO:v3-auto 등 구성
# Git commit SHA나 빌드 번호를 태그로 사용하는 경우도 다수 존재 -> 해시값
IMAGE_TAG="${IMAGE_TAG:-k8s-auto}"

# 필수 프로그램 검사
# 명령어 배열 정의
required_commands=(terraform aws kubectl docker python3)
# 배열에 있는 명령을 하나씩 반복
for command_name in "${required_commands[@]}"; do
  # 현재 명령이 설치되어 있는지 검사
  # command -v : 명령의 실행 경로를 찾음
  # ! -> 아래 조건을 부정하여 실패함을 잡아서 에러 처리
  # >/dev/null 2>&1 : 표준 출력과 표준 오류를 모두 버림
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    # >&2 : 메시지를 표준출력이 아니라 표준오류 stderr로 보냅
    echo "[ERROR] 필수 명령을 찾을 수 없습니다: ${command_name}" >&2
    # 스크립트를 실패 상태로 종료
    exit 1
  fi # if 종료
done # for 반복문 종료

# AWS 인증 검사
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "[ERROR] AWS CLI 인증이 필요합니다. aws configure 또는 AWS_PROFILE을 확인하세요." >&2
  exit 1
fi

# Docker daemon 검사
if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] Docker daemon이 실행 중이 아닙니다." >&2
  exit 1
fi

# Terraform 변수 파일 검사
if [[ ! -f "${INFRA_DIR}/terraform.tfvars" ]]; then
  echo "[ERROR] ${INFRA_DIR}/terraform.tfvars 파일이 없습니다." >&2
  echo "cp 01-infra/terraform.tfvars.example 01-infra/terraform.tfvars 후 다시 실행하세요." >&2
  exit 1
fi

###########################################################
# 1. terraform으로 infra 구성
###########################################################
# 1. VPC, NAT, EKS Auto Mode, Metrics Server, RDS, ECR 생성
# -chdir : Terraform 작업 디렉터리를 infra로 지정
terraform -chdir="${INFRA_DIR}" init
# -auto-approve : 사용자 입력 없이 자동 승인 -> yes 자동 처리 -> 삭제시도 자동 처리
# 인프라 구성
terraform -chdir="${INFRA_DIR}" apply -auto-approve

# Terraform이 만든 리소스 정보를 셸 스크립트에 전달하는 연결 지점
# Terraform Output을 셸 변수로 가져오기 -> outputs.tf에 반드시 정의 되어 있어야함
# 변수="$(terraform ... output -raw 출력이름)"

# 리전
AWS_REGION="$(terraform -chdir="${INFRA_DIR}" output -raw aws_region)"
# 생성된 EKS 클러스터 이름
CLUSTER_NAME="$(terraform -chdir="${INFRA_DIR}" output -raw cluster_name)"
# WEB 애플리케이션의 ECR Repository URL
WEB_REPO="$(terraform -chdir="${INFRA_DIR}" output -raw web_ecr_repository_url)"
# WAS 애플리케이션의 ECR Repository URL
WAS_REPO="$(terraform -chdir="${INFRA_DIR}" output -raw was_ecr_repository_url)"
# RDS 접속 주소
RDS_HOST="$(terraform -chdir="${INFRA_DIR}" output -raw rds_endpoint)"
# RDS 포트
RDS_PORT="$(terraform -chdir="${INFRA_DIR}" output -raw rds_port)"
# RDS 안에서 사용할 데이터베이스 이름
RDS_DB_NAME="$(terraform -chdir="${INFRA_DIR}" output -raw rds_db_name)"
# RDS 마스터 계정 정보를 저장한 AWS Secrets Manager Secret의 ARN
RDS_SECRET_ARN="$(terraform -chdir="${INFRA_DIR}" output -raw rds_master_secret_arn)"

# kubectl과 EKS 연결
# 로컬의 kubectl이 생성된 EKS 클러스터를 사용할 수 있도록 kubeconfig를 업데이트
# 통상 kubeconfig 위치는 ~/.kube/config
# Terraform으로 클러스터를 생성한 뒤, 바로 그 클러스터에 Kubernetes 리소스를 배포하기 위한 연결 단계
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"
# 다음 정보 등록
# EKS API Server 주소
# 클러스터 인증서 정보
# AWS CLI를 이용한 인증 방식
# Kubernetes context
# 현재 사용할 context

# # Metrics Server Add-on 확인
# Metrics Server의 준비 상태를 확인
# kube-system Namespace에 있는 metrics-server Deployment가 정상적으로 배포될 때까지 기다림
# deployment/metrics-server : 확인할 Deployment 이름
# -n kube-system : 시스템 구성요소가 배치되는 kube-system Namespace를 대상
# --timeout=15m : 최대 15분 동안 대기, 그 이후에는 실패로 간주
kubectl rollout status deployment/metrics-server -n kube-system --timeout=15m
# 정상 : deployment "metrics-server" successfully rolled out
# Metrics Server가 준비되지 않은 상태에서 HPA를 적용하면 CPU나 메모리 지표를 사용할 수 없음


##################################################
# 2. Docker 이미지 빌드와 ECR Push
#    WEB과 WAS 애플리케이션을 Docker 이미지로 만들고 ECR에 업로드
#    Kubernetes Deployment는 이후 이 ECR 이미지를 Pull해 Pod를 생성함
##################################################
# # 2. 애플리케이션 이미지를 ECR에 빌드·Push

# WEB Repository URL에서 Repository 이름을 제거하고 ECR Registry 주소만 추출
# WEB_REPO="123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/de-ai-25-web"
# ECR_REGISTRY="123456789012.dkr.ecr.ap-northeast-2.amazonaws.com" <- 이렇게 처리
# ${변수%%패턴} => ${WEB_REPO%%/*} => /부터 뒤에 있는 모든 내용을 제거
ECR_REGISTRY="${WEB_REPO%%/*}"

# Docker 로그인 이후에만 다음 docker push가 ECR에 이미지를 업로드할 수 있음
# AWS ECR 로그인 토큰을 받아 Docker에 전달
# aws ecr get-login-password --region "${AWS_REGION}" : AWS 자격증명을 이용하여 ECR 로그인용 비밀번호 획득
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
# | docker login --username AWS --password-stdin "${ECR_REGISTRY}" : 앞 명령의 결과를 Docker 로그인 명령에 전달

# WEB Docker 이미지를 빌드
docker build --platform linux/amd64 -t "${WEB_REPO}:${IMAGE_TAG}" "${ROOT_DIR}/apps/web"
# 빌드된 WEB 이미지를 ECR에 업로드
docker push "${WEB_REPO}:${IMAGE_TAG}"

# WAS 애플리케이션 이미지를 빌드
docker build --platform linux/amd64 -t "${WAS_REPO}:${IMAGE_TAG}" "${ROOT_DIR}/apps/was"
# WAS 이미지를 ECR에 업로드
docker push "${WAS_REPO}:${IMAGE_TAG}"


################################################
# 3. Secrets Manager에서 RDS 계정 조회
#    RDS 계정 정보를 코드에 직접 적지 않고 AWS Secrets Manager에서 읽겠다
################################################
# AWS Secrets Manager
#        ↓ AWS CLI
# 셸 변수
#        ↓ kubectl
# Kubernetes Secret
#        ↓
# WAS Pod 환경변수

# # 3. RDS 관리 비밀번호를 파일이나 Terraform state에 저장하지 않고 Kubernetes Secret으로 전달
# Secrets Manager에서 Secret 값을 가져와 SECRET_JSON 변수에 저장
# --secret-id "${RDS_SECRET_ARN}" : 조회할 Secret을 ARN으로 지정
# --query SecretString : AWS CLI 전체 응답 중 SecretString 필드만 선택
# 응답 샘플
# {
#   "ARN": "...",
#   "Name": "...",
#   "VersionId": "...",
#   "SecretString": "{\"username\":\"admin\",\"password\":\"...\"}"
# }
# --output text : JSON 객체 형태가 아니라 텍스트로 출력
SECRET_JSON="$(aws secretsmanager get-secret-value \
  --region "${AWS_REGION}" \
  --secret-id "${RDS_SECRET_ARN}" \
  --query SecretString \
  --output text)"

# JSON 문자열에서 username 값을 추출
DB_USER="$(SECRET_JSON="${SECRET_JSON}" python3 -c 'import json,os; print(json.loads(os.environ["SECRET_JSON"])["username"])')"
# JSON 문자열에서 password 값을 추출
DB_PASSWORD="$(SECRET_JSON="${SECRET_JSON}" python3 -c 'import json,os; print(json.loads(os.environ["SECRET_JSON"])["password"])')"
# 현재 셸에서 SECRET_JSON 변수를 제거
unset SECRET_JSON

# Namespace가 없으면 생성하고, 이미 있으면 그대로 유지하거나 갱신
# --dry-run=client : Kubernetes API Server에 생성 요청을 보내지 않고 로컬에서 YAML만 만듬
# -o yaml : 결과를 YAML 형식으로 출력
# kubectl apply -f - : 파이프로 전달된 YAML을 Kubernetes에 적용
# 여러 번 실행해도 오류 없이 적용할 수 있는 멱등성 있는 구성
kubectl create namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Kubernetes Secret 생성
# create secret generic rds-secret : rds-secret이라는 일반형 Kubernetes Secret을 생성할 YAML을 준비
# generic : Key-Value Secret
# --namespace "${APP_NAMESPACE}" : Secret을 애플리케이션 Namespace에 생성
# --from-literal="DB_HOST=${RDS_HOST}" : RDS 호스트 주소를 Secret에 너음
# RDS_PORT, RDS_DB_NAME, DB_USER, DB_PASSWORD도 Secret에 추가
# --dry-run=client -o yaml | kubectl apply -f - : Secret을 직접 create하지 않고 YAML을 생성한 뒤 apply
kubectl create secret generic rds-secret \
  --namespace "${APP_NAMESPACE}" \
  --from-literal="DB_HOST=${RDS_HOST}" \
  --from-literal="DB_PORT=${RDS_PORT}" \
  --from-literal="DB_NAME=${RDS_DB_NAME}" \
  --from-literal="DB_USER=${DB_USER}" \
  --from-literal="DB_PASSWORD=${DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 현재 셸에서 DB_PASSWORD DB_USER 변수를 제거
unset DB_PASSWORD DB_USER


################################################
# 4. Kubernetes Manifest 적용
#    Auto Mode IngressClass, WEB/WAS, Service, HPA, PDB 적용
#    render_manifest.py가 다음 Kubernetes 리소스를 생성
#    Manifest 파일에 ECR 주소나 Namespace를 직접 하드코딩하지 않고 실행 시점에 동적
################################################
# 셸 변수 APP_NAMESPACE를 자식 프로세스의 환경변수로 전달 -> 파이썬 프로세스가 읽을 수 있음
export APP_NAMESPACE
# WEB 이미지 전체 주소를 환경변수로 설정하고 export
export WEB_IMAGE="${WEB_REPO}:${IMAGE_TAG}"
# WAS 이미지 전체 주소를 환경변수로 설정하고 export
export WAS_IMAGE="${WAS_REPO}:${IMAGE_TAG}"
# Python 프로그램이 Kubernetes Manifest를 만들어 표준출력으로 내보내고, 그 결과를 바로 Kubernetes에 적용
python3 "${ROOT_DIR}/render_manifest.py" | kubectl apply -f -


#################################################
# 5. EKS Auto Mode Node 생성과 Deployment 확인
#################################################
# 애플리케이션 Deployment를 적용하면 Pod가 생성
# 실행할 Node가 없거나 자원이 부족하면 Pod는 Pending 상태가 됨
# EKS Auto Mode는 Pod의 요구사항을 보고 적절한 Node를 생성
# Deployment 생성
#    ↓
# Pod 생성
#    ↓
# 배치 가능한 Node 없음
#    ↓
# Pod Pending
#    ↓
# EKS Auto Mode가 Node 필요성 감지
#    ↓
# NodeClaim 생성
#    ↓
# EC2 Node 생성
#    ↓
# Pod 스케줄링
#    ↓
# Pod Running
# WAS Deployment가 정상적으로 배포될 때까지 최대 20분 기다림
#   - 정상 완료 조건은 Deployment가 요구하는 수의 Pod가 Ready 상태가 되는 것
#   - WEB이 WAS를 호출하는 구조이므로 WAS가 먼저 준비되는 것이 중요
#   - 두 Deployment는 이미 89행에서 함께 적용되었기 때문에 실제 생성은 병렬로 진행
kubectl rollout status deployment/was -n "${APP_NAMESPACE}" --timeout=20m
# WEB Deployment가 정상적으로 배포될 때까지 기다림
kubectl rollout status deployment/web -n "${APP_NAMESPACE}" --timeout=20m
# Node 판단
# → EC2 인스턴스 생성
# → Node 클러스터 등록
# → ECR 이미지 Pull
# → Container 실행
# → Readiness Probe 성공
# 기존 Node가 이미 있는 경우보다 시간이 더 걸릴 수 있어 20분을 설정
# kubectl apply가 성공한 것을 배포 성공으로 보지 않고, 실제 Pod가 준비될 때까지 확인



#####################################################
# 6. 배포 완료 안내
#    배포된 EKS 클러스터 이름, 애플리케이션이 배포된 Namespace를 출력
#    사용자가 다음에 실행할 Auto Mode 확인 명령을 안내
######################################################
# kubectl get nodepool,nodeclass,nodeclaim,nodes\n
#     - NodePool	어떤 종류의 Node를 만들 수 있는지에 대한 정책
#     - NodeClass	AWS EC2, Subnet, Security Group 등 인프라 설정
#     - NodeClaim	실제로 하나의 Node를 요청한 상태
#     - Node	Kubernetes에 등록된 실제 Worker Node
######################################################
# kubectl get ingress public-alb -n %s -w\n
#    Ingress가 생성한 Public ALB 주소를 확인하는 명령
#    - -w : watch 옵션. Ingress 상태가 변경될 때마다 화면을 갱신
#####################################################
# kubectl get pods,svc,ingress,hpa,pdb -n %s\n
#     - pods	Pod	실제 실행 중인 WEB/WAS 컨테이너
#     - svc	Service	Pod 접근을 위한 내부 고정 주소
#     - ingress	Ingress	외부 ALB 라우팅
#     - hpa	HorizontalPodAutoscaler	부하에 따른 Pod 수 자동 조절
#     - pdb	PodDisruptionBudget	유지보수 중 최소 가용 Pod 보호
#####################################################
printf '\n============================================================\n'
printf 'EKS Auto Mode v3 배포 완료\n'
printf 'Cluster   : %s\n' "${CLUSTER_NAME}"
printf 'Namespace : %s\n' "${APP_NAMESPACE}"
printf '\nAuto Mode 리소스 확인:\n'
printf 'kubectl get nodepool,nodeclass,nodeclaim,nodes\n'
printf '\nALB 주소 확인:\n'
printf 'kubectl get ingress public-alb -n %s -w\n' "${APP_NAMESPACE}"
printf '\n전체 애플리케이션 상태:\n'
printf 'kubectl get pods,svc,ingress,hpa,pdb -n %s\n' "${APP_NAMESPACE}"
printf '============================================================\n'


# 결론 
# Terraform이 AWS 기반을 만들고, 
# Docker가 애플리케이션 이미지를 ECR에 올리고, 
# AWS Secrets Manager의 RDS 계정을 Kubernetes Secret으로 전달한 뒤, 
# render_manifest.py가 생성한 WEB/WAS 관련 리소스를 EKS Auto Mode에 배포하고 
# 정상 상태까지 기다리는 
# 전체 자동화 오케스트레이션 스크립트