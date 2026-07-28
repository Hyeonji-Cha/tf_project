# 개요
- 테라폼 작성 주요 문법

# 준비
- syntax.tf 생성
    - 초기화
    ```
        terraform init
    ```

# 구성 절차
- 작성(init->plan, validate, fmt, graph,....)
- 실행(apply)
- 결과(output)
    - 결과값은 알파벳(사전) 순으로 정렬
    - HCL(HashiCorp Configuration Language) 읽어서 -> 그래프 구성(DAG) -> 실행
        - 리소스간 의존성 계산 (먼저 생성할것 들, 참조할것 들)
        - output은 map으로 관리(키,값)

# 변수
- 타입 -> 값의 형태로 결정
```
string, number, bool, list, map, object
```
- 예제 출력 결과 -> 알파벳순
```
age = 100
books = [
  "1",
  "2",
]
is_mz = true
name = "테라폼"
stations = "테라폼"
```
- 변수의 의미 (`variable` -> Input Variable vs `locals` (Local Values) )
    - 목적: 재사용되는 값 변수로 정의하여 일괄관리, 외부에서 받아오는 입력값 대응
    - 재사용성(여러 리소스등에서 사용), 동적 설정(외부, `-var 옵션` or  `.tfvars` )

- 외부 입력하여 수정1
```
# 생성(수행) 단계에서 매개변수로 전달하여(외부) 변수값 수정
terraform apply -var="age=99" -var="is_mz=false"
---
# 코드 변경없이 매개변수로 다른 구성을 생성할수 있음
age = "99"  <- 수정
books = [
  "1",
  "2",
]
is_mz = "false" <- 수정
name = "테라폼"
stations = "테라폼"
```

- 외부 입력하여 수정2
    - 변수 2개 추가
        ```
            terraform apply
            ---
            environment = "dev"
            instance_count = 1
        ```
    - terraform.tfvars, dev.tfvars, prod.tfvars 2개 준비
        - terraform.tfvars(or *.auto.tfvars) 생성/내용 작성해 둔다
            - terraform apply 수행시 자동으로 읽어서 변수값 변경함(외부에서 설정)
        - dev.tfvars(개발용), prod.tfvars(서비스용, 프로덕션) -> 용도별로 인프라 구성 가능
            ```
                # 개발 환경으로 인프라 구성(배포)하시오
                terraform apply -var-file="dev.tfvars" 
            ```
        
    - 적용

# locals
- 코드 내부에서만 상뇽하는 상수, 계산값등, 외부에서 수정 x

# Function (함수)
```
# 문자열 지원
upper()
lower()
join()
split()
... (숫자, 컬렉션(list/set/.), 맵)
```

# for_each (반복)
- 계획된 여러 타입/변수등 반복적으로 리소스에 반영하여 구성한다면 유용
- 반복 주체 : 리소스
- 반복 결과 : 리소스 여러개 생성
```
for_each_value = {
  "db" = "t3.medium"
  "was" = "t3.small"
  "web" = "t3.micro"
}
```

# count
- 리소스는 기본 1개 생성 컨셉
- 속성으로 count를 부여하여 수치를 세팅 => 수치만큼 생성됨
```
resource "..." "was"{
    ...
    count = 3  # was용 리소스를 같은 스펙에서 3개 생성함
    ...
}
```
- 실습 basic의 *.tf코드 복사하여 tf-step2로 붙여넣기 
```
    # 코드 수정후
    terraform init
    terraform apply
    # 확인
    terraform destroy
```

# Dynamic (반복)
- 중첩 블록을 반복하여 생성하는 문법
- 대상 : 블록 -> 블록이 n개 생성
- 사용 : resource 내부
- ex)
    - 보안 그룹에서 ingress 여러 포트를 오픈할때 유용
    - 실제 구성은 web-was-db의 보안그룹을 각각 구성할때 진행

```
resource "aws_security_group" "DE-AI-25-IaC-TF-GROUP" {
  ...
  # 포트만 다르고, 나머지 구성은 동일 => 패턴은 동일하되, 값이 동일/다르거나의 반복
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ...
}
# 다이나믹 적용
locals = {
    ports = [22, 443, 80]
}
resource "aws_security_group" "DE-AI-25-IaC-TF-GROUP" {
    dynamic "ingress" {
        for_each = locals.ports # 3회 반복임을 인지함(선언)
        content {
            protocol    = "tcp"         # 고정
            cidr_blocks = ["0.0.0.0/0"] # 고정
            # dynamic "ingress" 이렇게 선언 햇으므로 값은 ingress.value로 사용
            from_port   = ingress.value # for_each에 설정된 값을 순서대로 접근 (22->443->80)
            to_port     = ingress.value
            
        }
    }
}
```

# lifecycle (생명주기)
- 리소스의 생명주기를 어떻게 관리 할 것인지 메타 인자
- 동작 : 생성, 수정, 교체, 삭제 기반으로 파생되어 구성
- 주요 유형
    - 삭제 하지 않겟다 => prevent_destroy
        - EIP -> 고정 IP
        - RDS (데이터베이스) -> 데이터
        - S3 Bucket (객체 저장소-> 저장 단위(버킷/바구니) -> 유지) -> 데이터
        - Route53 -> 도메인
        - 프로젝트간 영속 저장/유지 대상
        ```
            resource "aws_eip" "DE-AI-25-IaC-TF-EIP" {          
                instance = aws_instance.DE-AI-25-IaC-TF.id          
                domain = "vpc"
                # 삭제 하지 않는다!! => terraform destroy 수행시 에러 발생하고 넘어감
                lifecycle {
                        prevent_destroy = true
                }
            }
        ```
    - 삭제하기 전에 먼저 생성하고 나서 삭제한다 (교체하는 컨셉, 서비스 중단(Downtime)에 대한 대처)
        - create_before_destroy
        - 테라폼은 삭제 => 생성 흐름을 기본으로 가지고 있음
            - 서비스 중단이 잠시 발생됨 
            - 대처 : 새 리소스 생성 => 이후 기존 리소스 삭제
        ```
            ...
                lifecycle {
                    create_before_destroy = true
                }
            ...
        ```

# workspace (작업공간)
- count 폴더(신규 생성) 하위에 상관없는 *.tf 이동 시킴(실습상 격리)
    - 리소스 생성 코드등 배제하고 작업공간만 확인
- workspace 목록 조회
    ```
        terraform workspace list
        ---
        # * : 현재 사용중인(활성화된) workspace 표시
        # default : 기본으로 만들어지는 workspace임
        * default
    ```
- workspace 생성 (기본, 개발, 테스트, 운영,... : 상태정보)
    ```        
        terraform workspace select dev
        --- 
        # 없다면
        Workspace "dev" doesn't exist.
        You can create this workspace with the "new" subcommand 
        or include the "-or-create" flag with the "select" subcommand.

        # 생성 -> 활성화(*) 이동
        terraform workspace new dev
        ---
        Created and switched to workspace "dev"!
        You're now on a new, empty workspace. Workspaces isolate their state,
        so if you run "terraform plan" Terraform will not see any existing state
        for this configuration.

        # 조회
        terraform workspace list
        ---
        default
        * dev

        # 특정 상태 선택 
        terraform workspace select default
        ---
        Switched to workspace "default"

        # 목록
        terraform workspace list
        ---
        * default
        dev

        # 현재 상태 확인
        terraform workspace show
        ---
        default

        # 삭제 -> list 하면 dev가 않보임
        terraform workspace delete dev
        ---
        Deleted workspace "dev"!

    ```

- 환경별(상태별) 별도 state를 기반으로 소스코드등 관리

# state (리소스 상태 조회)
- apply  생성 이후 내용에 대한 조회
```
# 새로 생성된 리소스 목록 출력
terraform state list
---
data.aws_ami.amazon_linux
data.aws_subnets.default
data.aws_vpc.default
aws_instance.DE-AI-25-IaC-TF
aws_security_group.DE-AI-25-IaC-TF-GROUP

# 상세 조회 (리소스가 만들어진후 확인 가능하다 plan보이는 내용들)
# terraform state show 리소스
terraform state show aws_instance.DE-AI-25-IaC-TF
---
# aws_instance.DE-AI-25-IaC-TF:
resource "aws_instance" "DE-AI-25-IaC-TF" {
    ami                                  = "ami-01e99d46e612f3624"
    arn                                  = "arn:aws:ec2:ap-northeast-2:827913617635:instance/i-06cca307a4999d54a"
    associate_public_ip_address          = true
    availability_zone                    = "ap-northeast-2c"
    disable_api_stop                     = false  <- 생성 이후 세팅된 값들
    disable_api_termination              = false
    ebs_optimized                        = false
    force_destroy                        = false
    get_password_data                    = false
    hibernation                          = false
    host_id                              = null
    iam_instance_profile                 = null
    id                                   = "i-06cca307a4999d54a"
    instance_initiated_shutdown_behavior = "stop"
    instance_lifecycle                   = null
    instance_state                       = "running"
    instance_type                        = "t3.micro"
    ipv6_address_count                   = 0
    ipv6_addresses                       = []
    key_name                             = "DE-AI-25-TEST"
    monitoring                           = false
    outpost_arn                          = null
    password_data                        = null
    placement_group                      = null
    placement_group_id                   = null
    placement_partition_number           = 0
    primary_network_interface_id         = "eni-0eff638cd47e73c41"
    private_dns                          = "ip-172-31-45-87.ap-northeast-2.compute.internal"
    private_ip                           = "172.31.45.87"
    public_dns                           = "ec2-13-124-172-214.ap-northeast-2.compute.amazonaws.com"
    public_ip                            = "13.124.172.214"
    region                               = "ap-northeast-2"
    secondary_private_ips                = []
    security_groups                      = [
        "terraform-25-sg2",
    ]
    source_dest_check                    = true
    spot_instance_request_id             = null
    subnet_id                            = "subnet-049c8f72bb109a11e"
    tags                                 = {
        "Name" = "DE-AI-25-IaC-TF-EC2"
    }
    tags_all                             = {
        "Name" = "DE-AI-25-IaC-TF-EC2"
    }
    tenancy                              = "default"
    user_data                            = <<-EOT
        #!/bin/bash
        dnf install -y ec2-instance-connect
    EOT
    user_data_replace_on_change          = false
    vpc_security_group_ids               = [
        "sg-0ba323064169e7174",
    ]

    capacity_reservation_specification {
        capacity_reservation_preference = "open"
    }

    cpu_options {
        amd_sev_snp           = null
        core_count            = 1
        nested_virtualization = null
        threads_per_core      = 2
    }

    credit_specification {
        cpu_credits = "unlimited"
    }

    enclave_options {
        enabled = false
    }

    maintenance_options {
        auto_recovery = "default"
    }

    metadata_options {
        http_endpoint               = "enabled"
        http_protocol_ipv6          = "disabled"
        http_put_response_hop_limit = 2
        http_tokens                 = "required"
        instance_metadata_tags      = "disabled"
    }

    primary_network_interface {
        delete_on_termination = true
        network_interface_id  = "eni-0eff638cd47e73c41"
    }

    private_dns_name_options {
        enable_resource_name_dns_a_record    = false
        enable_resource_name_dns_aaaa_record = false
        hostname_type                        = "ip-name"
    }

    root_block_device {
        delete_on_termination = true
        device_name           = "/dev/xvda"
        encrypted             = false
        iops                  = 3000
        kms_key_id            = null
        tags                  = {}
        tags_all              = {}
        throughput            = 125
        volume_id             = "vol-0db3bba5af41cb419"
        volume_size           = 2
        volume_type           = "gp3"
    }
}

```