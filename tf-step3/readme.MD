# 목표
- 회사 전용으로 클라우드 내 네트워크 구축 -> VPC
- 현재 EC2는 default VPC사용 -> 전용 VPC로 직접 생성하여 적용
- VPC만 구축
    - EC2에 커스텀 VPC연결하여 인프라 구성
    - web(public subnet), was/db(private subnet)확장 + NAT gateway, SSH Manager, IAM Role
    - 소스코드, 쿠버네티스, CI/CD
    - 대시보드(그라파타, 프로메테우스)

    # 구성
    - AWS
        - VPC
        - CIDR
        - Public/Private Subnet
        - Internet Gateway
        - NAT Gateway
        - Route Table/Route Table Assoication
        - ..

# VPC (Virtual Private Cloud)
## 정의
- AWS(클라우드 생태계) 안에 내가(개인/기업) `직접 만드는 사설 네트워크`
- AWS 안에 나만(개인/기업) 사용하는 독립된(격리된) 네트워크 공간

## 현실세계 비유
- AWS : 도시/국가(생태계)
- VPC : 수많은 아파트 단지 (클라우드 관점 : 개인/회사 단독 사용)
- subnet : 동(101동, 102동,..)
- EC2 : 각 집(세대, 101호, 102호...)
- Internet Gateway : 아파트 정문 (외부 통신 가능, 트레픽 나가고, 들어오고 가능)
    - Subnet은 public 형태(개방)   
- Route table : 안내 표지판 (주소, 길, 방향)
- Security Group : 각 세대(집) 현관문 보안장치( 출입 통제 -> 포트/IP 제약(인바운드,아웃바운드))
- NACL(Network Access Control List) : 아파트 동/단지 출입 통제 (VPC를 위한 보안 계층)
--------------
- NAT Gateway : 
    - Private Subnet을 위해서 구성
        - 외부에서 Private Subnet으로 접근 x
        - s/w 설치를 해야하는 경우, 소스코드 획득 등 내부에서 외부의 자원을 가져올 필요가 있음(pull)
        - 이를 위해서 NAT gateway 가 필요함

## 구성원 1 
### VPC
    - Default VPC
        - 리전별 n개 구성 (통상 자동으로 만들어져 있음)
        - EC2 구성시 바로 사용 가능(퍼블릭 기본 세팅)
        - 학습, 테스트시 유용
        - 나만의 VPC x
    - [v] Custom VPC
        - 하위 구성원들 직접 구성(설계)
        - 운영환경등 활용
        - 나만의 VPC o