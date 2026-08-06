# ─────────────────────────────────────────────
# IngressClassParams
# EKS ALB의 기본 옵션 설정
# ─────────────────────────────────────────────
# IngressClassParams
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams            # ALB 생성 옵션 정의 리소스
metadata:
  name: alb
spec:
  scheme: internet-facing           # 외부 인터넷에서 접속 가능한 Public ALB 생성
---

# ─────────────────────────────────────────────
# IngressClass
# Ingress를 AWS ALB와 연결하는 클래스 설정
# ─────────────────────────────────────────────
apiVersion: networking.k8s.io/v1
kind: IngressClass                      # Ingress를 처리할 Controller 정의
metadata:
  name: alb                             # 이름, ingress 파트에서 사용
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true" # ALB를 기본 IngressClass로 지정
spec:
  controller: eks.amazonaws.com/alb     # AWS EKS의 ALB 컨트롤러가 Ingress 담당
  parameters:                           # 리소스 상세정보 연결
    apiGroup: eks.amazonaws.com         # 리소스 EKS API 그룹
    kind: IngressClassParams            # 리소스 종류
    name: alb                           # 리소스 이름
---

# ─────────────────────────────────────────────
# Namespace
# ─────────────────────────────────────────────
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
---

# ─────────────────────────────────────────────
# WAS Pod에 관련된 Deployment, Service, PDB, HPA
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# Deployment (Pod 개수, 복구, 버전에 따른 교체 등을 총괄 관리하는 정책 구성)
# Kubernetes가 가동되면 시스템 구성, 데이터베이스, 리소스 객체 등이 생성·설정됨
# Control Plane : Kubernetes 관리 시스템
# etcd          : Kubernetes 내에 각각 업무를 수행하는 객체들을 저장하는 데이터베이스
# Deployment    : etcd에 저장되어 있는 Kubernetes API 리소스 객체로 Pod 관리 업무 수행
# ─────────────────────────────────────────────

apiVersion: apps/v1               # Deployment 기능을 제공하는 API 버전 
                                  # (고정값, 버전 차이가 추후 존재할 수 있음)
kind: Deployment                  # 파드의 생성, 복구, 개수 유지 담당
metadata:                         # Deployment 기본 정보
  name: was                       # Deployment 이름
  namespace: ${APP_NAMESPACE}     # Deployment 리소스 객체가 생성되는 Namespace
spec:                             # Deployment의 실제 설정
  replicas: 2                     # WAS Pod는 기본적으로 최소 2개를 실행하도록 설정
  selector:                       # Pod 선택 조건
    matchLabels:                  # Label을 기준으로 Web/WAS Pod 선택
      app: was                    # app=was Label을 가진 Pod를 관리
  template:                       # Deployment가 관리하는 파드의 설계도
    metadata:                     # 기본정보
      labels:                     # 라벨
        app: was                  # app=was, Deployment가 Pod 생성 시 Pod를 찾는 조건
        tier: backend             # backend 담당이라는 커스텀 라벨
    spec:                         # 실제 실행 정보
      topologySpreadConstraints:  # 파드를 여러 가용 영역에 분산 배치
        - maxSkew: 1              # AZ별 파드 개수 차이는 최대 1개로 제한
          minDomains: 2           # 최소 2개, 가용 영역에 분산
          topologyKey: topology.kubernetes.io/zone   # 분산 기준(가용영역)을 AZ로 지정
          whenUnsatisfiable: DoNotSchedule           # 분산 조건을 만족하지 않으면 배치하지 않음
          labelSelector:          # 분산 규칙을 따르는 파드는 -
            matchLabels:          # 라벨이 일치하는 파드만 적용
              app: was            # app=was로 구성된 Pod에만 적용

      containers:                 # 파드 내부 컨테이너 설정
        - name: was               # 컨테이너 명
          image: ${WAS_IMAGE}     # ECR 이미지 주소이며 인프라 구성과 이미지 Push 후 전달받아 설정
          imagePullPolicy: Always # Pod 시작 시 저장소에서 이미지 존재 여부 확인
          ports:                  # 컨테이너 사용 포트
            - name: http          # 포트명
              containerPort: 8000 # FastAPI가 사용하는 8000번 포트
          envFrom:                # 외부로부터 환경변수를 받아서 설정
            - secretRef:          # Kubernetes Secret 참조
                name: rds-secret  # RDS 접속 정보 저장되어 있음 > 이름 적용
          resources:              # 컨테이너 구성 시 Node/Pod로부터 할당받는 자원
            requests:             # 최소 자원
              cpu: 100m           # cpu 0.1개
              memory: 128Mi       # 메모리 128Mi
            limits:               # 제한 (최대치) 
              cpu: 500m           # cpu 0.5개
              memory: 512Mi       # 메모리 512Mi
          readinessProbe:         # 요청을 받은 준비가 되었는가 검사
            httpGet:              # http 요청 상태 확인 (get 방식)
              path: /health       # url, api 경로
              port: http          # http라는 이름으로 규정된 8000번 포트 사용
            initialDelaySeconds: 5 # 컨테이너 시작 후 5초 뒤 첫 검사 진행
            periodSeconds: 10      # 10초 간격 검사
            timeoutSeconds: 3      # 3초 안에 응답 없으면 실패
            failureThreshold: 3    # 연속 3회 실패하면 요청 대상에서 제외 -> 비정상판단
          livenessProbe:          # 컨테이너가 정상적인가 검사
            httpGet:              # http 요청 상태 확인 (get 방식)
              path: /health       # url, api 경로
              port: http          # http라는 이름으로 규정된 8000번 포트 사용
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
---

# ─────────────────────────────────────────────
# Service
# Web Pod가 WAS Pod에 접근할 수 있는 내부 주소 제공(중간 역할)
# 이 Service를 거쳐 요청이 이동
# ─────────────────────────────────────────────
apiVersion: v1
kind: Service                   # 여러 WAS Pod에 고정된 단일 접근 주소 제공
metadata:                       # 기본 정보
  name: was-service             # 이름
  namespace: ${APP_NAMESPACE}   # 생성 위치
spec:
  selector:                     # 요청을 전달할 파드 선택 조건
    app: was                    # app=was 라벨을 가진 파드만 대상
  ports:                        # 포트    
    - name: http                # 포트 이름
      port: 8000                # 포트 번호 
      targetPort: http          # 대상 WAS Pod의 포트 이름인 http 사용
  type: ClusterIP               # 클러스터 내부에서만 접근 가능한 Service
---

# ─────────────────────────────────────────────
# PodDisruptionBudget (PDB)
# 계획된 작업 중 WAS Pod가 모두 중단되는 상황을 방지
# ─────────────────────────────────────────────
apiVersion: policy/v1         
kind: PodDisruptionBudget       # 파드 중단 허용 범위 정의, 관리
metadata:
  name: was-pdb                 # PDB 이름
  namespace: ${APP_NAMESPACE}   # 소속 Namespace
spec:
  minAvailable: 1               # WAS 파드는 최소 1개 이상 유지
  selector:                     # 보호할 대상을 지정
    matchLabels:
      app: was                  # Label 값 중 app=was인 Pod에 대한 정책
---

# ─────────────────────────────────────────────
# HorizontalPodAutoscaler (HPA)
# CPU 사용량(판단기준)에 따라 WAS 파드의 수를 자동 조절(Autoscaler) <-> ASG
# ─────────────────────────────────────────────
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler     # 파드의 수를 자동 조절(확대, 축소)
metadata:
  name: was-hpa                   # HPA의 이름
  namespace: ${APP_NAMESPACE}     # Namespace 소속(이 공간 내에서 생성)
spec:                             # 실제 설정
  scaleTargetRef:                 # scale할 대상 참조
    apiVersion: apps/v1
    kind: Deployment              # scale 대상은 Deployment
    name: was                     # WAS Deployment를 대상으로 지정
  minReplicas: 2                  # 최소 WAS Pod 수 2
  maxReplicas: 6                  # 최대 WAS Pod 수 6
  behavior:                               # 파드 확장, 축소 동작 설정
    scaleDown:                            # 축소(Pod 수를 줄일 때)
      stabilizationWindowSeconds: 300     # 부하 감소 후 300초간 관찰한 뒤 축소
  metrics:                        # 판단 지표
    - type: Resource              # CPU, 메모리 리소스 지표 사용
      resource:
        name: cpu                 # CPU 사용량 대상
        target:
          type: Utilization       # requests.cpu 대비 CPU 사용률 기준
          averageUtilization: 60  # 전체 WAS Pod의 평균 CPU 목표를 60%로 설정
---

# ─────────────────────────────────────────────
# Web Pod에 관련된 Deployment, Service, PDB, HPA
# ─────────────────────────────────────────────
# Deployment (상동, 세부값만 일부 상이함)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
        tier: frontend
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          minDomains: 2
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
      containers:
        - name: web
          image: ${WEB_IMAGE}
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3
---

# Service
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: ${APP_NAMESPACE}
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: http
  type: ClusterIP
---

# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: ${APP_NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: web
---

# HorizontalPodAutoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: ${APP_NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 6
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
---

# ─────────────────────────────────────────────
# Ingress
# 외부에서 들어온 요청을 Public ALB를 통해 Web Service로 전달
# ─────────────────────────────────────────────
apiVersion: networking.k8s.io/v1
kind: Ingress                       # 외부 요청의 진입 경로와 전달 규칙 정의
metadata:
  name: public-alb                  # 이름
  namespace: ${APP_NAMESPACE}       # 생성 위치
spec:
  ingressClassName: alb             # ALB IngressClass 사용
  rules:                            # 룰
    - http:                         # http 요청 처리
        paths:                      # 경로들
          - path: /                 # 루트 경로
            pathType: Prefix        # /로 시작하는 모든 하위 경로 포함
            backend:                # 요청을 전달할 백엔드 설정
              service:              # 서비스 지정
                name: web-service   # web-service로 전달
                port:
                  number: 80        # 80번 포트로 전달
