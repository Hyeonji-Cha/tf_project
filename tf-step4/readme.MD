- private 서브넷 구성
- 3-tier 구성
- NAT Gateway 배치
```
                    Internet
                        │
                Internet Gateway
                        │
                Public Route Table
                        │
      ┌─────────────────┴─────────────────┐
      │                                   │
 Public Subnet (10.0.1.0/24)        Private Subnet (10.0.2.0/24) <- ssm Manager 방식
      │                                   │
      │                                   │
 ┌────────────┐                    ┌────────────┐
 │ Web EC2    │                    │ WAS EC2    │
 │ nginx      │     -(SSH)->       │ FastAPI    │
 └────────────┘                    └────────────┘
                                          │
                                    ┌────────────┐
                                    │ DB EC2     │
                                    │ MySQL      │
                                    └────────────┘
                                          

# 리소스 구성
AWS
L VPC
    L Internet Gateway
        L public Route Table
            L Public Subnet
                L EC2 (Web) - SG (22, 80, 443) - EIP
    -------------------------------------------------
    L NAT Gateway
        L Private Route Table
            L Private Subnet
                L EC2 (Was) - SG (22, 8000)
                L EC2 (Db)  - SG (22, 3306)

# 예상되는 작업
- 퍼블릭 서브넷 활용
    - 반복 표현으로 구성
        - SG는 반복 구성 (locals, for_each, dynamic 활용)
        - EC2는 반복 구성 (locals, for_each, dynamic 활용)

- 프라이빗 서브넷 구성
    - Private Subnet
    - Private Route Table
    - association
    - EC2 조정