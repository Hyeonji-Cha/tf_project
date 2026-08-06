# ────────────────────────────────────────────────
# EKS Auto Mode ALB 설정
# 외부 인터넷에서 접근할 수 있는 Public ALB 구성
# ────────────────────────────────────────────────
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: alb
spec:
  # 인터넷에 공개되는 ALB
  scheme: internet-facing

---
# ────────────────────────────────────────────────
# ALB Ingress Class
# Kubernetes Ingress가 EKS Auto Mode의 ALB를 사용하도록 설정
# ────────────────────────────────────────────────
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    # 별도의 Ingress Class를 지정하지 않으면 기본적으로 이 Class 사용
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  # EKS Auto Mode ALB Controller
  controller: eks.amazonaws.com/alb
  parameters:
    apiGroup: eks.amazonaws.com
    kind: IngressClassParams
    name: alb

---
# ────────────────────────────────────────────────
# 애플리케이션 Namespace
# Web, WAS, Service, HPA 등의 리소스를 하나의 공간에 구성
# ────────────────────────────────────────────────
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}

---
# ────────────────────────────────────────────────
# WAS Deployment
# 백엔드 애플리케이션 Pod 구성
# ────────────────────────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: was
  namespace: ${APP_NAMESPACE}
spec:
  # 기본 WAS Pod 수
  replicas: 2

  # 이 Deployment가 관리할 Pod 선택
  selector:
    matchLabels:
      app: was

  # 생성할 Pod 설정
  template:
    metadata:
      labels:
        app: was
        tier: backend

    spec:
      # WAS Pod를 서로 다른 가용 영역에 분산 배치
      topologySpreadConstraints:
        - maxSkew: 1
          minDomains: 2
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: was

      containers:
        - name: was

          # ECR에 Push된 WAS 이미지
          image: ${WAS_IMAGE}

          # Pod 생성 시 항상 원격 저장소에서 이미지 확인
          imagePullPolicy: Always

          # WAS 애플리케이션 포트
          ports:
            - name: http
              containerPort: 8000

          # RDS 접속 정보를 Kubernetes Secret에서 환경변수로 주입
          envFrom:
            - secretRef:
                name: rds-secret

          # WAS Pod가 요청하는 최소 자원과 최대 사용 한도
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi

          # 요청을 받을 준비가 되었는지 확인
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          # 컨테이너가 정상적으로 동작 중인지 확인
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3

---
# ────────────────────────────────────────────────
# WAS Service
# 클러스터 내부에서 WAS Pod에 접근할 수 있는 고정 주소 제공
# ────────────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: was-service
  namespace: ${APP_NAMESPACE}
spec:
  # app: was 라벨을 가진 Pod로 요청 전달
  selector:
    app: was

  ports:
    - name: http
      port: 8000
      targetPort: http

  # 클러스터 내부에서만 접근 가능
  type: ClusterIP

---
# ────────────────────────────────────────────────
# WAS PodDisruptionBudget
# 유지보수 및 Pod 축출 중에도 최소 1개의 WAS Pod 유지
# ────────────────────────────────────────────────
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: was-pdb
  namespace: ${APP_NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: was

---
# ────────────────────────────────────────────────
# WAS Horizontal Pod Autoscaler
# CPU 사용률에 따라 WAS Pod 수를 자동 조절
# ────────────────────────────────────────────────
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: was-hpa
  namespace: ${APP_NAMESPACE}
spec:
  # 확장 또는 축소할 대상 Deployment
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: was

  # WAS Pod 수 범위
  minReplicas: 2
  maxReplicas: 6

  # Pod 축소 시 300초 동안 안정화 상태 확인
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300

  # 평균 CPU 사용률 60%를 목표로 Pod 수 조절
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60

---
# ────────────────────────────────────────────────
# Web Deployment
# 프런트엔드 애플리케이션 Pod 구성
# ────────────────────────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ${APP_NAMESPACE}
spec:
  # 기본 Web Pod 수
  replicas: 2

  # 이 Deployment가 관리할 Pod 선택
  selector:
    matchLabels:
      app: web

  # 생성할 Pod 설정
  template:
    metadata:
      labels:
        app: web
        tier: frontend

    spec:
      # Web Pod를 서로 다른 가용 영역에 분산 배치
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

          # ECR에 Push된 Web 이미지
          image: ${WEB_IMAGE}

          # Pod 생성 시 항상 원격 저장소에서 이미지 확인
          imagePullPolicy: Always

          # Web 애플리케이션 포트
          ports:
            - name: http
              containerPort: 80

          # Web Pod가 요청하는 최소 자원과 최대 사용 한도
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 300m
              memory: 256Mi

          # 요청을 받을 준비가 되었는지 확인
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          # 컨테이너가 정상적으로 동작 중인지 확인
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3

---
# ────────────────────────────────────────────────
# Web Service
# ALB의 요청을 Web Pod로 전달
# ────────────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: ${APP_NAMESPACE}
spec:
  # app: web 라벨을 가진 Pod로 요청 전달
  selector:
    app: web

  ports:
    - name: http
      port: 80
      targetPort: http

  # 클러스터 내부에서만 접근 가능
  type: ClusterIP

---
# ────────────────────────────────────────────────
# Web PodDisruptionBudget
# 유지보수 및 Pod 축출 중에도 최소 1개의 Web Pod 유지
# ────────────────────────────────────────────────
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
# ────────────────────────────────────────────────
# Web Horizontal Pod Autoscaler
# CPU 사용률에 따라 Web Pod 수를 자동 조절
# ────────────────────────────────────────────────
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: ${APP_NAMESPACE}
spec:
  # 확장 또는 축소할 대상 Deployment
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web

  # Web Pod 수 범위
  minReplicas: 2
  maxReplicas: 6

  # Pod 축소 시 300초 동안 안정화 상태 확인
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300

  # 평균 CPU 사용률 60%를 목표로 Pod 수 조절
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60

---
# ────────────────────────────────────────────────
# Public ALB Ingress
# 외부 요청을 Web Service로 전달
# ────────────────────────────────────────────────
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: public-alb
  namespace: ${APP_NAMESPACE}
spec:
  # 위에서 정의한 ALB Ingress Class 사용
  ingressClassName: alb

  # 외부 요청 라우팅 규칙
  rules:
    - http:
        paths:
          # 루트 경로 이하의 모든 요청을 Web Service로 전달
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
