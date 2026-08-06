# 목표
- v1 버전기반 쿠버네티스 도입, 구조 변경, 새로운 개념 정리(운영/관리)
- 쿠버네티스를 디테일하게 직접 구성 or [v]auto mode로 구성(관리파트) -> EKS, ECR 활용

# 쿠버네티스
- 컨테이너를 여러 서버에 배치, 장애 발생시 복구, 트레픽에 따라 확장/감소하는 시스템
- 수많은 컨테이너화된 애프리케이션의 배포, 확장, 관리을 자동화하는 오픈소스 기반의 `컨테이너 오케스트레이션 표준 플랫폼`
- 여러 서버(물리/가상)에 걸쳐 컨테이너의 그룹화, 무중단 배포, 로드밸런싱, 자가 치유(복구)등을 수행
- 클러스터 단위로 작동
    - 구성
        - 전체 클러스터의 두뇌 역할: Control Plane이며 Amazon EKS가 관리
        - 실제 컨테이너 애플리케이션을 구동: Data Plane(Worker Node)이며 EKS Auto Mode가 Node 생성·축소와 관련 네트워크·스토리지 기능을 자동화

# 쿠버네티스 구조
- 쿠버네티스 중심 기반 구성
![쿠버네티스 중심 기반 구성](./쿠버네티스구조_2.png)

- AWS EKS 기반 구성
![AWS EKS 기반 구성](./쿠버네티스구조_1.png)

- 트래픽 흐름도
```
                         Internet
                            │
                            ▼
                 AWS Application Load Balancer
                            │
                      Kubernetes Ingress
                            │
                            ▼
                    Web Service(ClusterIP)
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          Web Pod 1                 Web Pod 2
        Nginx Container           Nginx Container
                │
                └───────────┬───────────┘
                            │
                            ▼
                    WAS Service(ClusterIP)
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          WAS Pod 1                 WAS Pod 2
        FastAPI Container         FastAPI Container
                │                       │
                └───────────┬───────────┘
                            │
                            ▼
                     Amazon RDS MySQL
                      Multi-AZ 구성
```

# 개별 요소 역할
- Control Plane : 마스터 노드
- Data Plane : 워커 노드(Worker Node)

| Kubernetes      | AWS에서 실제 반영되는 대상          | 역할                   |
| --------------- | ------------------------- | -------------------- |
| 두뇌 - Control Plane  |  |  |
| Control Plane   | EKS 관리 영역                 | API, 스케줄링, 상태 관리     |
|    | API Server    | kubectl(CLI 명령어)·YAML(구성플랜) 요청(명령) 접수  |
|    | Scheduler     | Pod가 실행될 Node 결정 - 요청에 대한 처리 누가 할지 (노드 선택)  |
|    | Controller    | 원하는 상태와 실제 상태 비교 - 차이가 있으면 반영  |
|    | etcd          | 클러스터 선언·상태 저장  |
| Auto Mode       | EKS 관리 기능                 | Node 생성·축소와 관련 네트워크·스토리지 기능 자동화 |
| 클러스터 - Data Plane |  |  |
| Cluster         | Amazon EKS                | Kubernetes 전체 환경, 1개 클러스터 내에서 Namespace로 프로젝트별 리소스를 논리적으로 격리      |
|             | Ingress         | 외부 라우팅 규칙, Application Load Balancer         |
|             | Deployment         | Pod 개수·버전·복구 관리         |
|             | HPA · PDB         | 확장과 최소유지등 가용성 정책 <br>Kubernetes + Metrics, <br>Pod 수 자동 증가·감소 처리          |
|             | ConfigMap · Secret         | 설정과 민감정보 주입 <br> Kubernetes Secret, DB 계정 및 암호 전달         |
| Node            | Auto Mode 관리형 컴퓨팅         | Pod가 실행되는 물리적 서버, EKS에서는 EC2, AZ-a~d 까지 가용영역에 n개 배치됨         |
| Pod             | Node 내부 컨테이너              | Pod 안에는 통상 1개(필요시 n개) 컨테이너, <br/>Nginx, FastAPI 실행,<br/>Web Pod(내부에 nginx 컨테이너)    |
| Service         | Kubernetes 내부 네트워크        | 변경되는 WEB Pod를 하나의 고정 주소로 묶음 <br/>Pod 간 고정 접속 주소, WEB Service, WAS Service       |
| VPC 네트워크        | VPC/Subnet/ENI            | Node와 Pod 통신         |
| 기타 구성 | |  |
| Container Image | Amazon ECR                | WEB/WAS 이미지 저장       |
| Database        | Amazon RDS                | MySQL 데이터 저장         |

# Terraform Kubernetes/EKS Auto Mode 구성
## 비교
- V1(금) : ALB, ASG, EC2, RDS등 활용하여 AWS 고가용성 인프라 구성, EC2 서버를 효율적 운영
- V2(월) : 쿠버네티스 기반
    - 컨테이너 기반 어플리케이션의 배포/복구/확장의 자동화, 오케스트레이션
    - 버전
        - 직접 세밀하기 구성
            - Kubernetes의 내부 운영 구조를 직접 상세하게 구성
        - Pod 하위 단위 인프라에 집중 구성
            - EKS Auto Mode 구성
                - Amazon EKS가 Control Plane을 관리하고, EKS Auto Mode가 Node의 생성·축소와 관련 네트워크·스토리지 기능을 자동화
                - Kubernetes 핵심 리소스에 집중(Pod, Deployment, Service, Ingress, HPA, PDB)
                    - Data Plane에 집중
    - 장점
        - 배포 표준화:	        
            - WEB와 WAS를 Docker 이미지로 만들고, 동일한 이미지를 개발·테스트·운영 환경에 배포 (`컨터이너` 사용에 대한 이득)

        - 자동 장애 복구:
            - Pod가 종료(강제,장애,기타 사유)되면 `Deployment가 새로운 Pod를 자동 생성`
            - 컨테이너 기반으로 간단하게 처리됨

        - 빠른 확장:	           
            - HPA가 트래픽과 자원 사용량에 따라 `Pod 개수를 조절` (오토 스케일링 유사 -> 지표 -> 매트릭 서버(add on 필요)를 통해 데이터 획득)

        - 서비스 연결 단순화:	    
            - Web이 변경되는 WAS Pod IP 대신 `was-service`라는 고정 이름으로 접근
            - 내부에서 Pod가 생성·삭제되어 IP가 변경되어도 Service가 고정 접근 지점을 제공하므로 서비스 연결을 유지

        - 무중단 업데이트:	   
            - 기존 Pod를 한꺼번에 종료하지 않고 새 버전으로 `순차 교체`

        - 고가용성:	        
            - `Pod를 여러 Node와 가용영역에 분산` (Multi-AZ)

        - 선언형 관리:	     
            - 서버에 접속해 직접 수정하지 않고 `YAML(쿠버네티스 구성)`과 `Terraform(인프라, tf)`으로 원하는 상태를 정의
            - 단, 인프라 구성 후 Kubernetes 적용 시 인프라 요소를 참조할 수 있는 ID 값이 필요하므로 템플릿(`app.yaml.tpl`)에 값을 전달하여 동적으로 YAML 구성

        - CI/CD 연계:	   
            - GitHub Actions, ECR, ArgoCD와 연결해 이미지 빌드부터 배포까지 자동화

        - 서비스 확장 대응:	
            - WEB·WAS 외에 배치, 데이터 처리(데이터 엔진니어 요소, airflow), 모니터링(프로메테우스, 그라파타) 등 서비스가 늘어도 동일한 방식으로 관리

# 구조 설계
## ~/infra 내 Terraform 파일
1. [v]`01_versions.tf` — Terraform/AWS Provider 버전
2. [v]`02_variables.tf` — 외부 입력값 -> tfvars 로 세팅값으로 변경 가능함
3. [v]`03_locals.tf` — 입력값을 조합한 공통 이름·서브넷 Map·태그
4. [v]`04_provider.tf` — AWS 리전과 공통 태그
```
# 중간 점검
# -chdir="tf가 존재하는 경로" => 해당 위치에 tf에 대해 작업 진행
~/tf-step6> terraform -chdir="./infra"  init
# 포맷
~/tf-step6> terraform -chdir="./infra"  fmt
# 검사
~/tf-step6> terraform -chdir="./infra"  validate
# 플랜
~/tf-step6> terraform -chdir="./infra"  plan
# 적용 -> output을 구성하여 결과 확인
~/tf-step6> terraform -chdir="./infra"  apply
```

5. [v]`05_vpc.tf` — VPC, 6개 Subnet, IGW, NAT Gateway, Route Table
```
~/tf-step6> terraform -chdir="./infra"  apply
---
aws 콘솔 > vpc > 리소스맵 > 네트워크 구성 확인

~/tf-step6> terraform -chdir="./infra"  destroy
```
6. [v]`06_iam.tf` — EKS Cluster Role과 Auto Mode Node Role
```
- 삭제 시 해당 IAM Role이 삭제되지 않으면 자동화 구성 시 오류가 발생할 수 있음(중복 역할 생성)
```
7. [v]`07_logging.tf` — EKS Control Plane CloudWatch Log Group

8. [v]`08.eks.tf` — EKS Control Plane, Auto Mode, Metrics Server, Access Entry
9. [v]`09_security.tf` — EKS Cluster Security Group에서 RDS 3306 접근 허용
10. [v]`10_ecr.tf` — WEB/WAS 이미지 저장소와 이미지 정리 정책 - ci/cd 관련
11. [v]`11_rds.tf` — 비공개 MySQL Multi-AZ 및 Secrets Manager 암호

12. `12_output.tf` — 배포 스크립트가 사용할 생성 결과

## ~/apps web, was 이미지 생성, 소스코드, Dockerfile -> ci/cd 영향받음
- web
    - Dockerfile : 이미지 생성용 Dockerfile
    - index.html : 홈페이지(/) 프런트코드(html, css, js)
        - Ingress → Web Service → Web Pod → WAS Service → WAS Pod 연결 확인
        - Ingress → Web Service → Web Pod → WAS Service → WAS Pod → RDS 연결 확인
    - nginx.conf : 프록시 구성 환경설정 파일 (web->was, 기타설정)
        - was에 대해 upstream 구성으로 정의, 8000번 포트등 설정
        - /health : 즉시 응답 구성 ( web pod가 잘 작동 하고 있음을 보여주는 응답 )
        - /api/   : was pod 방향으로 포워딩
        - /       : index.html 응답
- was
    - app.py : fastapi 작성된 백엔드 코드
    - Dockerfile : 이미지 생성용 도커파일
    - requirements.txt : 필수 패키지


## ~/k8s 쿠버네티스 구성 파일
- app.yaml.tpl
    - 인프라 구성후 참조할 리소스값등을 구성 파일에 전달하기 위해 템플릿 형태로 구성
    - `${APP_NAMESPACE}`, `${WEB_IMAGE}`, `${WAS_IMAGE}` 변수를 필요한 위치에서 사용

## Windows PowerShell 배포 및 삭제
- 현재 Windows PowerShell 실습의 전체 배포 실행 파일은 `apply-all-v2.bat`이다.
- `apply-all.bat`은 이전 Windows 배포 스크립트이며 현재 실습에서는 사용하지 않고 보관한다.
- `apply-all.sh`와 `destroy-all.sh`는 WSL 또는 Git Bash 환경에서 사용하는 Bash 스크립트이며, 현재 Windows PowerShell 실습에서는 실행하지 않고 보관한다.
- Windows 삭제 실행 파일은 `destroy-all.bat`이다.

### 실행 전 준비 사항
- Terraform
- AWS CLI v2
- kubectl
- Docker Desktop
- Python 3
- AWS 인증 설정
- Docker Desktop 실행 상태

### 실행 위치 및 명령
다음 경로는 개인 PC의 실행 예시이다.

```powershell
cd C:\Users\NT551_11TH\Desktop\workspace\tf_project\tf-step6
.\apply-all-v2.bat
```

삭제할 때는 같은 위치에서 다음 명령을 사용한다.

```powershell
.\destroy-all.bat
```

### 전체 배포 흐름
`apply-all-v2.bat` 실행
→ 필수 프로그램과 AWS 인증 확인
→ Terraform으로 AWS 인프라 생성
→ EKS kubeconfig 설정
→ ECR 로그인
→ Web/WAS Docker 이미지 빌드 및 Push
→ Secrets Manager에서 RDS 접속 정보 조회
→ Kubernetes Namespace와 `rds-secret` 생성
→ `APP_NAMESPACE`, `WEB_IMAGE`, `WAS_IMAGE` 설정
→ `render_manifest.py`로 `k8s/app.yaml.tpl` 변수 치환
→ kubectl로 Kubernetes 리소스 적용
→ ALB → Web Service → Web Pod → WAS Service → WAS Pod → RDS

### render_manifest.py
- 위치: `tf-step6/render_manifest.py`
- 입력 환경변수: `APP_NAMESPACE`, `WEB_IMAGE`, `WAS_IMAGE`
- 템플릿: `k8s/app.yaml.tpl`
- 세 환경변수를 실제 값으로 치환하여 Kubernetes Manifest를 생성한다.
- 원본 `k8s/app.yaml.tpl`은 수정하지 않는다.
- 완성된 Manifest는 배포 단계에서 kubectl에 전달한다.
- 기본 Namespace는 `de-ai-18-cha`이다.
