# 개요
- 기본 구성
- EC2 구성
- 문법

# 작업 
## 기본 구성
- 기본 파일 생성 (작업 디렉토리 : ~/basic)
```
provider.tf
main.tf
variables.tf
outputs.tf
terraform.tfvars
.gitignore
```

- provider.tf 작성

## 인프라구성 
- step1 : 테라폼 초기화 (init)
```
terraform init
---
성공후 결과물
-> .terraform : 공급자 플러그인, 바이너리, 모듈캐시, 정보등 저장
-> .terraform.lock.hcl : 프로바이더의 모듈의 정확한 버전, 해시값 잠금 -> 안정성, 자동생성시 체킹 파일
```

- step2 : 문법 검사(체킹) (validate)
```
terraform validate
---
Success! The configuration is valid.
```

- step3 : 실행 계획 확인 (플래닝, 시물레이션) (plan)
```
terraform plan
--- (현재 내용 없음)
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.
--- 실제
provider -> resource(보안그룹, VPC, EIP,..) 생성 계획
```

- step4 : 적용(실제 생성) (apply)
```
terraform apply
--- (현재는 인프라 구성 내용 x)
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no
changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
---
실제 : ec2 경우 1~2분 , 쿠버네티스등  10분 이내 등등 시간 소요
```

- step 5 : 인프라 삭제 (destroy)
```
terraform destroy
--- (삭제된것 없음. 만든것이 없어서)
No changes. No objects need to be destroyed.

Either you have not created any objects yet or the existing objects were already deleted outside of
Terraform.

Destroy complete! Resources: 0 destroyed.
```


## EC2 구성
### 최종 형태
```
Internet
     │
     │
Elastic IP       <- 리소스 생성
     │
┌──────────────┐
│     EC2      │
│ AmazonLinux2 │ <- 아마존 리눅스 사용/ec2-user
└──────────────┘
     │
Security Group   <- 보안그룹 전용 생성/0.0.0.0/0 개방/인바운드(ssh-22),아웃바운드(전체)
     │
VPC(Default)     <- 기본 사용

----
pem 파일, 스토리지, 리전, 이름, ...
```

### 세부 구성
- *.tf 파일 구성은 1개만 해도 OK, n개(리소스별등) 구성해도 Ok
- n개의 tf로 구성이 되도, 생성 순서에 따라 구동 흐름이 자동 조정됨(plan, garph 등 명령을 통해 확인 가능)
- variables.tf
    - 리전, 인스턴스 유형, 키이름 설정
    - provider.tf 변수 사용
    - 문법 검사
        ```
            terraform validate
            ---
            Success! The configuration is valid.
        ```
- provider.tf
     - 구성에 필요한 패키지등 사용 버전
     - 리전 등
- maim.tf
     - 통합적으로 구성(VPC(기본)-> SUBNETS(기본)->보안그룹(동적생성)-> OS 이미지 조회/선택(amazonLinux2->EC2생성 선언-> Elastic IP생성 연결))
     - 클라우드 내부에 나만 사용하는 사설네트워크(VPC관련 전체 리소스)만 제외하고 전체 구성을 동적으로 생성
     - data, resouce등 작성
          - 리소스 유형(https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
          - AWS VPC -> aws_vpc
          - AWS IAM Role -> aws_iam_role
          - <provider name>_<service name> or <provider name>_<service name>_<resource detail>
          - TF내부 고유명 : 커스텀가능
          ```
               data|resource "리소스유형(AWS 고정값)" "테라폼 내부 식별자(TF내부 고유명)" {
                    ...
               }
          ```
     - VPC는 리전별로 기본이 하나씩 구성되어 있다.
          - 현재ap-northeast-2[서울]의 기본 VPC는 서브넷 4개, 라우팅테이블 1개, 인터넷 게이트웨이 1개(서브넷 4개가 모두 연결되어 있음) 으로 구성되어있음. -> 어떤 서브넷을 사용하던 EC2는 외부에서 접속 가능한 구조임

     - 보안 그룹 생성(resource)하도록 선언
          - 작성(세부 설명은 코드에 삽입)
          - 실행 테스트
               ```
               # 자동 정렬  => = 를  기준으로 좌우 정렬 진행(주석에 따라 처리 않될수 있음-> 외부나 뒤쪽으로 배치선호)
               terraform fmt 
               ---
               main.tf
               outputs.tf
               provider.tf

               # 유효성 검사
               terraform validate
               ---
               Success! The configuration is valid.

               # 플랜 => 이렇게 만들것이다
               terraform plan
               ---
               ..
               symbols:
                    + create  <= + 생성
               ...
                    하위 모든 리소스 에서 + 형태로 확인됨
               ... 
               요약
               Plan: 1 to add, 0 to change, 0 to destroy

               # 적용
               terraform apply

               # aws 보안 그룹 확인 -> aws 대시보드

               # 삭제
               terraform destroy
               ---
                    - destroy : 삭제(제거) 처리 
               ...
                    하위 모든 리소스 에서 - 형태로 확인됨
               ... 
               요약
               Plan: 0 to add, 0 to change, 1 to destroy.
               ```
     
     - AMI(Amazon Machine Image) OS 이미지 조회
          - 사전에 어떤 제품을 사용하겠다 선정함(아마존 리눅스)
          - 목표 : ami-xxxx로 표기되는 이미지값 획득
          ```
          terrafomr apply
          ---
               ...
               aws_ami_amazon_linux_id = "ami-0f93dc65265863858" <- 아이디 조회됨
               ...
          ```
          - data.aws_ami.amazon_linux 정보를 출력하여 전체 정보 확인 가능
     
     - EC2 생성 선언
          - 재료(vpc, subnets, 보안그룹, ami, 인스턴스유형(직접지정), pem파일 ) 전부 이용하여 구성
          - plan
          ```
               symbols:
               + create

               Terraform will perform the following actions:

               # aws_instance.DE-AI-25-IaC-TF will be created
               + resource "aws_instance" "DE-AI-25-IaC-TF" {
                    + ami                                  = "ami-0f93dc65265863858"
                    + arn                                  = (known after apply) <- 생성된 후에 확인가능
               
               ...
               Plan: 2 to add, 0 to change, 0 to destroy. <- 보안그룹, EC2 생성등 2개 리소스 생성으로 확정
          ```
          - apply
          ```
               ...
               aws_security_group.DE-AI-25-IaC-TF-GROUP: Creating...
               aws_security_group.DE-AI-25-IaC-TF-GROUP: Creation complete after 3s [id=sg-0e9ec5a5dca9c8f29]
               aws_instance.DE-AI-25-IaC-TF: Creating...
               aws_instance.DE-AI-25-IaC-TF: Still creating... [00m10s elapsed]
               aws_instance.DE-AI-25-IaC-TF: Creation complete after 12s [id=i-08491f3c0f269a12e]

               Apply complete! Resources: 2 added, 0 changed, 0 destroyed. <- 15초 소요

               Outputs:
               ... <- 현재 퍼블릭 IP 없음 (출력 처리 x)

          ```
          - destroy
          ```
               ...
               aws_instance.DE-AI-25-IaC-TF: Destruction complete after 1m0s <- 1분 소요
               ...
               Destroy complete! Resources: 2 destroyed. <- 2개 리소스 삭제
          ```

     - EIP 생성
          ```
          - apply
               
          ```

# basic 정리
- 기본 VPC/서브넷 사용 => 전용 VPC 필요함(개선)
- 보안그룹, ec2, eip => 동적 생성 연결
- 선언 및 표현
     - data         : 기존 aws 리소스 조회
     - resource     : 새로운 aws 리소스 생성
     - provider     : AWS 연결 설정, 버전등
     - *.tf
          - variable : 변수 정의 -> 설정값 분리 관리
          - output   : 테라폼의 수행(생성) 결과 출력
- 명령어
     - terraform fmt          : tf 코드의 자동 정렬
     - terraform validate     : 문법 검사
     - terraform init         : 초기화, 최초 필요한 공간, 실행파일등 세팅 (*.exe,..)
     - terraform plan         : apply 적용에 대한 계획 시뮬레이션 -> 검토
     - terraform apply        : 리소스 생성
     - terraform destroy      : 리소스 해제(삭제)
