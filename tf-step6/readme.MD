# 목표
- v1 버전기반 쿠버네티스 도입, 구조 변경, 새로운 개념 정리(운영/관리)
- 쿠버네티스를 디테일하게 직접 구성 or [v]auto mode로 구성(관리파트) -> EKS, ECR 활용

# 쿠버네티스
- 컨테이너를 여러 서버에 배치, 장애 발생시 복구, 트레픽에 따라 확장/감소하는 시스템
- 수많은 컨테이너화된 애프리케이션의 배포, 확장, 관리을 자동화하는 오픈소스 기반의 `컨테이너 오케스트레이션 표준 플랫폼`
- 여러 서버(물리/가상)에 걸쳐 컨테이너의 그룹화, 무중단 배포, 로드밸런싱, 자가 치유(복구)등을 수행
- 클러스터 단위로 작동
    - 구성
        - 전체 클러스터의 두뇌 역활 : 컨트롤 플레인(마스터 노드) -> auto mode시 자동구성
        - 실제 컨테이너 어플리케이션을 구동 : 데이터 플레인(워커 노드) <- auto mode 구성시 집중 파트

# 쿠버네티스 구조
- 쿠버네티스 중심 기반 구성
![쿠버네티스 중심 기반 구성](./쿠버네티스구조_2.png)

- AWS EKS 기반 구성
![AWS EKS 기반 구성](./쿠버네티스구조_1.png)

- 트레픽 흐름도
```
                         Internet
                            │
                            ▼
                 AWS Application Load Balancer
                            │
                      Kubernetes Ingress
                            │
                            ▼
                    WEB Service(ClusterIP)
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
          WEB Pod 1                 WEB Pod 2
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

# 개별 요소 역활
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
| Auto Mode       | EKS 관리 기능                 | Node 생성·축소와 네트워크 자동화, 컨트롤 플레인 역활 담당 |
| 클러스터 - Data Plane |  |  |
| Cluster         | Amazon EKS                | Kubernetes 전체 환경, 1개 클러스터 내에서 namespace로 쿠버네티스 프로젝트당 리소스 논리적 격기      |
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