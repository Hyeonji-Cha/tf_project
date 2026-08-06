@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

rem ============================================================
rem Windows용 EKS Auto Mode 전체 배포 스크립트
rem ============================================================

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "INFRA_DIR=%ROOT_DIR%\infra"

if not defined APP_NAMESPACE set "APP_NAMESPACE=de-ai-25"
if not defined IMAGE_TAG set "IMAGE_TAG=k8s-auto"
if not defined PYTHON_CMD set "PYTHON_CMD=python"

set "SECRET_JSON_FILE=%TEMP%\de-ai-25-rds-secret-%RANDOM%.json"
set "DB_ENV_FILE=%TEMP%\de-ai-25-rds-env-%RANDOM%.txt"

echo.
echo ============================================================
echo [1/7] Terraform으로 AWS 인프라를 생성합니다.
echo ============================================================
terraform -chdir="%INFRA_DIR%" init
if errorlevel 1 goto :error
terraform -chdir="%INFRA_DIR%" apply -auto-approve
if errorlevel 1 goto :error

call :terraform_output AWS_REGION aws_region
if errorlevel 1 goto :error
call :terraform_output CLUSTER_NAME cluster_name
if errorlevel 1 goto :error
call :terraform_output WEB_REPO web_ecr_repository_url
if errorlevel 1 goto :error
call :terraform_output WAS_REPO was_ecr_repository_url
if errorlevel 1 goto :error
call :terraform_output RDS_HOST rds_endpoint
if errorlevel 1 goto :error
call :terraform_output RDS_PORT rds_port
if errorlevel 1 goto :error
call :terraform_output RDS_DB_NAME rds_db_name
if errorlevel 1 goto :error
call :terraform_output RDS_SECRET_ARN rds_master_secret_arn
if errorlevel 1 goto :error

echo.
echo ============================================================
echo [2/7] EKS kubeconfig를 갱신합니다.
echo ============================================================
aws eks update-kubeconfig --region "%AWS_REGION%" --name "%CLUSTER_NAME%"
if errorlevel 1 goto :error
kubectl rollout status deployment/metrics-server -n kube-system --timeout=15m
if errorlevel 1 goto :error

echo.
echo ============================================================
echo [3/7] WEB/WAS 이미지를 빌드하고 ECR에 Push합니다.
echo ============================================================
for /f "tokens=1 delims=/" %%A in ("%WEB_REPO%") do set "ECR_REGISTRY=%%A"
aws ecr get-login-password --region "%AWS_REGION%" | docker login --username AWS --password-stdin "%ECR_REGISTRY%"
if errorlevel 1 goto :error

docker build --platform linux/amd64 -t "%WEB_REPO%:%IMAGE_TAG%" "%ROOT_DIR%\apps\web"
if errorlevel 1 goto :error
docker push "%WEB_REPO%:%IMAGE_TAG%"
if errorlevel 1 goto :error

docker build --platform linux/amd64 -t "%WAS_REPO%:%IMAGE_TAG%" "%ROOT_DIR%\apps\was"
if errorlevel 1 goto :error
docker push "%WAS_REPO%:%IMAGE_TAG%"
if errorlevel 1 goto :error

echo.
echo ============================================================
echo [4/7] RDS Secret을 Kubernetes Secret으로 전달합니다.
echo ============================================================
aws secretsmanager get-secret-value ^
  --region "%AWS_REGION%" ^
  --secret-id "%RDS_SECRET_ARN%" ^
  --query SecretString ^
  --output text > "%SECRET_JSON_FILE%"
if errorlevel 1 goto :error

%PYTHON_CMD% -c "import json,pathlib; d=json.loads(pathlib.Path(r'%SECRET_JSON_FILE%').read_text(encoding='utf-8')); lines=['DB_HOST=%RDS_HOST%','DB_PORT=%RDS_PORT%','DB_NAME=%RDS_DB_NAME%','DB_USER='+d['username'],'DB_PASSWORD='+d['password']]; pathlib.Path(r'%DB_ENV_FILE%').write_text('\n'.join(lines)+'\n', encoding='utf-8')"
if errorlevel 1 goto :error

kubectl create namespace "%APP_NAMESPACE%" --dry-run=client -o yaml | kubectl apply -f -
if errorlevel 1 goto :error
kubectl create secret generic rds-secret ^
  --namespace "%APP_NAMESPACE%" ^
  --from-env-file="%DB_ENV_FILE%" ^
  --dry-run=client -o yaml | kubectl apply -f -
if errorlevel 1 goto :error

del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1

echo.
echo ============================================================
echo [5/7] Kubernetes Manifest를 생성하고 적용합니다.
echo ============================================================
set "WEB_IMAGE=%WEB_REPO%:%IMAGE_TAG%"
set "WAS_IMAGE=%WAS_REPO%:%IMAGE_TAG%"
%PYTHON_CMD% "%ROOT_DIR%\render_manifest.py" | kubectl apply -f -
if errorlevel 1 goto :error

echo.
echo ============================================================
echo [6/7] WEB/WAS Deployment 배포 완료를 기다립니다.
echo ============================================================
kubectl rollout status deployment/was -n "%APP_NAMESPACE%" --timeout=20m
if errorlevel 1 goto :error
kubectl rollout status deployment/web -n "%APP_NAMESPACE%" --timeout=20m
if errorlevel 1 goto :error

echo.
echo ============================================================
echo [7/7] 배포 결과를 확인합니다.
echo ============================================================
kubectl get nodepool,nodeclass,nodeclaim,nodes
echo.
kubectl get pods,svc,ingress,hpa,pdb -n "%APP_NAMESPACE%"

echo.
echo ============================================================
echo EKS Auto Mode v3 배포 완료
echo Cluster   : %CLUSTER_NAME%
echo Namespace : %APP_NAMESPACE%
echo Image Tag : %IMAGE_TAG%
echo.
echo ALB 주소 확인:
echo kubectl get ingress public-alb -n %APP_NAMESPACE% -w
echo ============================================================
goto :success

:terraform_output
set "%~1="
pushd "%INFRA_DIR%" >nul
for /f "usebackq delims=" %%A in (`terraform output -raw %~2`) do set "%~1=%%A"
popd >nul
if not defined %~1 (
    echo [ERROR] Terraform output을 읽지 못했습니다: %~2
    exit /b 1
)
exit /b 0

:error
set "EXIT_CODE=%ERRORLEVEL%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1
echo.
echo ============================================================
echo [ERROR] 배포 중 오류가 발생했습니다.
echo 종료 코드: %EXIT_CODE%
echo ============================================================
exit /b %EXIT_CODE%

:success
del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1
exit /b 0