# 구성 버전
## V1 
- infrastructure Enginnering : 운영 가능한 인프라 구축
```
Terraform -> Production AWS -> 3-tier -> Multi AZ(멀티존) -> ALB(어플리케이션 로드밸런서) -> ASG(오토스케일링그룹) -> RDS

SSM System Manager를 통해서 ec2에 접속 (pem 배제)
```

## V2
- Plafrom Enginnering : 컨테이너 플랫폼 구축 -> 쿠버네티스 기반으로 전체 재구성
```
Terraform -> EKS -> Container -> Deployment -> Serive -> ingress 
```

## V3
- Devops : CI/CD
```
Github -> GitAction/ArgoCD -> ECR -> EKS
```

## V4
- Obserability : 운영 및 모니터링
```
Prometheus -> Grafana -> Metrics -> Alert (슬랙등..)
```

# Infrastructure Enginnering : 운영 가능한 인프라 구축
- 특징
    - 테라폼으로 운영 인프라 전체를 구축    
    - 고가용성
        - Web1이 장애 발생/부하 높게 걸리면 (CPU 50% 초과) -> `ALB`가 Web2로 트레픽 우회
        - 트레픽 분산 > 장애 대응 전략
    - 확장성
        - 접속 증가/감소 -> 직접 ec2 개수 증가/감수 -> 자동관리 구성
        - `AGS(Auto Scaling Group)` == 쿠버네티스 replica
    - 불변 인프라
        - Ec2 구성 => `Launch Template` 사용 > 신규 Ec2 생성 > 자동 설치 > 서비스 자동 시작
        - 서버 내용이 수정 => Launch Template 반응 => EC2 순차적 교체 => Ec2 오드버전 순차 삭제 (무중단 구성 ) == 쿠버네티스의 컨테이너 교체
    - 로드 밸런싱
        - 고가용성에 대한 구체적 시나리오
        - 버전별 
            - v0(기존) : client -> web
            - v1(금일) : client -> ALB(EIP 연결) -> web1 or web2
            - v2(차주) : Ingress -> Serive -> pod
    - 데이터베이스 분리 운영
        - db는 AWS 전용 rds 서비스 사용 -> 생성시간이 대략 10분 소요
    - 운영형 아킥텍쳐        
    - 쿠버네티스로 자연스럽게 확장 연동 대체 가능한 구조
        - 각 파트별 대체 가능
    
# 구성도
- 트래픽 이동(api 요청, 웹페이지 요청, request)
```
Internet
   │
Public ALB
   │
WEB Auto Scaling Group
├─ WEB EC2 / AZ-a
└─ WEB EC2 / AZ-c
   │
Internal ALB
   │
WAS Auto Scaling Group
├─ WAS EC2 / AZ-a
└─ WAS EC2 / AZ-c
   │
RDS MySQL Multi-AZ
├─ Primary
└─ Standby
```

- 용어정리
    - Region : 서울 -> 서비스 지역
        L Availability Zone(AZ) : 리전 내부에 독립된 데이터센터 영역 (서울내 4개 독릭영역(a,b,c,d))
            L Subnet : 독립 가용영역 안에 생성하는 네트워크 (설정한 만큼 생성 가능)

- 네트워크 구조 (2개의 가용 영역, 각각 서브넷 구성(퍼블릭 1개, 프라이빗 2개))
```
ap-northeast-2a               ap-northeast-2c
───────────────────────────────────────────────
Public-A                       Public-C
├─ Public ALB                  ├─ Public ALB
└─ NAT Gateway-A               └─ NAT Gateway-C

App-Private-A                  App-Private-C
├─ WEB ASG                     ├─ WEB ASG
├─ Internal ALB                ├─ Internal ALB
└─ WAS ASG                     └─ WAS ASG

DB-Private-A                   DB-Private-C
└─ RDS Primary/Standby         └─ RDS Primary/Standby
```

# 파일구조
tf-step5/
L variables.tf : tf 전체에 사용한 값 정의 (상수같이 활용)
L locals.tf    : 신규, 반복용 값 세팅
L iam.tf       : 신규, SSM 처리 역활, 프로파일 구성, 접속관련
L provider.tf  : 공급자 정보, 리전, 공용 태그(전체 리소스 영향)

L vpc.tf       : vpc, subnet, igw, nat gateway, route table/az 연결/alb, web/was, db 연결 
L sg.tf        : 보안 그룹 -> ALB, WEB, Interal ALB, WAS, DB
L alb.tf       : 신규 로그밸런서 구성, 작동방식
L asg.tf       : 신규 오토 스케일링 그룹 전략, 장애 발생시 대응, 내용 업그레이드시 교체 전략, 증감 조건 (CPU 50% 기준(예시)) 정책

L data.tf      : 리소스 조회, AMI
L launch_template.tf : 신규
L rds.tf       : 신규 rds 구성
L userdata-web.sh.tftpl : 테라폼 템플릿 파일, web ec2 구성시 초기해 세팅해야할 내용 쉘스크립트 구성등 내용 포함
L userdata-was.sh.tftpl : 테라폼 템플릿 파일, was ec2 구성시 초기해 세팅해야할 내용 쉘스크립트 구성등 내용 포함