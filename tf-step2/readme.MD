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

# Function(함수)

