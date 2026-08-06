@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

rem ============================================================
rem Windows용 EKS Auto Mode 전체 배포 스크립트
rem ============================================================

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "INFRA_DIR=%ROOT_DIR%\infra"

if not defined APP_NAMESPACE set "APP_NAMESPACE=de-ai-18-cha"
if not defined IMAGE_TAG set "IMAGE_TAG=k8s-auto"

set "SECRET_JSON_FILE=%TEMP%\de-ai-18-cha-rds-secret-%RANDOM%.json"
set "DB_ENV_FILE=%TEMP%\de-ai-18-cha-rds-env-%RANDOM%.txt"
set "RENDERED_MANIFEST_FILE=%TEMP%\de-ai-18-cha-app-rendered-%RANDOM%.yaml"

rem ============================================================
rem [0/7] 필수 프로그램 및 실행 환경 검사
rem ============================================================

echo.
echo ============================================================
echo [0/7] 필수 프로그램과 실행 환경을 검사합니다.
echo ============================================================

call :check_command terraform
if errorlevel 1 goto :precheck_error

call :check_command aws
if errorlevel 1 goto :precheck_error

call :check_command kubectl
if errorlevel 1 goto :precheck_error

call :check_command docker
if errorlevel 1 goto :precheck_error

rem Python은 Windows 환경에 따라 python 또는 py -3를 사용한다.
if defined PYTHON_CMD (
    %PYTHON_CMD% --version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] PYTHON_CMD로 지정된 Python 명령을 실행할 수 없습니다: %PYTHON_CMD%
        goto :precheck_error
    )
) else (
    where python >nul 2>&1
    if not errorlevel 1 (
        python --version >nul 2>&1
        if not errorlevel 1 set "PYTHON_CMD=python"
    )

    if not defined PYTHON_CMD (
        where py >nul 2>&1
        if not errorlevel 1 (
            py -3 --version >nul 2>&1
            if not errorlevel 1 set "PYTHON_CMD=py -3"
        )
    )

    if not defined PYTHON_CMD (
        echo [ERROR] 필수 명령을 찾을 수 없습니다: Python 3
        echo         python 또는 py 명령이 Windows PATH에 등록되어 있어야 합니다.
        goto :precheck_error
    )
)

echo [OK] Python: %PYTHON_CMD%

rem AWS CLI 인증 검사
aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [ERROR] AWS CLI 인증이 필요합니다.
    echo         aws configure 또는 AWS_PROFILE 설정을 확인하세요.
    goto :precheck_error
)
echo [OK] AWS CLI 인증

rem Docker daemon 검사
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker daemon이 실행 중이 아닙니다.
    echo         Docker Desktop을 실행한 후 다시 시도하세요.
    goto :precheck_error
)
echo [OK] Docker daemon

rem Terraform 디렉터리 검사
if not exist "%INFRA_DIR%\" (
    echo [ERROR] Terraform 디렉터리가 없습니다:
    echo         %INFRA_DIR%
    goto :precheck_error
)
echo [OK] Terraform 디렉터리

rem Terraform 변수 파일 확인
rem terraform.tfvars가 있으면 해당 파일을 사용하고, 없으면 02_variables.tf의 기본값을 사용한다.
if exist "%INFRA_DIR%\terraform.tfvars" (
    echo [OK] Terraform 변수 파일을 사용합니다:
    echo      %INFRA_DIR%\terraform.tfvars
) else (
    echo [INFO] terraform.tfvars가 없습니다. 02_variables.tf의 기본값을 사용합니다.
)

rem render_manifest.py 검사
if not exist "%ROOT_DIR%\render_manifest.py" (
    echo [ERROR] Kubernetes Manifest 생성 파일이 없습니다:
    echo         %ROOT_DIR%\render_manifest.py
    goto :precheck_error
)
echo [OK] render_manifest.py

rem WEB/WAS Dockerfile 검사
if not exist "%ROOT_DIR%\apps\web\Dockerfile" (
    echo [ERROR] WEB Dockerfile이 없습니다:
    echo         %ROOT_DIR%\apps\web\Dockerfile
    goto :precheck_error
)
echo [OK] WEB Dockerfile

if not exist "%ROOT_DIR%\apps\was\Dockerfile" (
    echo [ERROR] WAS Dockerfile이 없습니다:
    echo         %ROOT_DIR%\apps\was\Dockerfile
    goto :precheck_error
)
echo [OK] WAS Dockerfile

echo.
echo 사전 검사가 완료되었습니다.

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

%PYTHON_CMD% -c "import json,pathlib; d=json.loads(pathlib.Path(r'%SECRET_JSON_FILE%').read_text(encoding='utf-8-sig')); lines=['DB_HOST=%RDS_HOST%','DB_PORT=%RDS_PORT%','DB_NAME=%RDS_DB_NAME%','DB_USER='+d['username'],'DB_PASSWORD='+d['password']]; pathlib.Path(r'%DB_ENV_FILE%').write_text('\n'.join(lines)+'\n', encoding='utf-8')"
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

%PYTHON_CMD% "%ROOT_DIR%\render_manifest.py" > "%RENDERED_MANIFEST_FILE%"
if errorlevel 1 goto :error

kubectl apply -f "%RENDERED_MANIFEST_FILE%"
if errorlevel 1 goto :error

del /q "%RENDERED_MANIFEST_FILE%" >nul 2>&1

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


rem ============================================================
rem 필수 Windows 명령 검사
rem where 명령은 Windows PATH에서 실행 파일을 검색한다.
rem ============================================================
:check_command
where %~1 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 필수 명령을 찾을 수 없습니다: %~1
    echo         설치 여부와 Windows PATH 설정을 확인하세요.
    exit /b 1
)

echo [OK] %~1
exit /b 0


rem ============================================================
rem Terraform output 값을 Windows 환경변수에 저장
rem 사용 예: call :terraform_output AWS_REGION aws_region
rem ============================================================
:terraform_output
set "%~1="

pushd "%INFRA_DIR%" >nul
if errorlevel 1 (
    echo [ERROR] Terraform 디렉터리로 이동할 수 없습니다:
    echo         %INFRA_DIR%
    exit /b 1
)

for /f "usebackq delims=" %%A in (`terraform output -raw %~2`) do set "%~1=%%A"
popd >nul

if not defined %~1 (
    echo [ERROR] Terraform output을 읽지 못했습니다: %~2
    exit /b 1
)

exit /b 0


:precheck_error
del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1
del /q "%RENDERED_MANIFEST_FILE%" >nul 2>&1

echo.
echo ============================================================
echo [ERROR] 사전 검사에 실패했습니다.
echo 위 오류를 해결한 후 apply-all-v2.bat를 다시 실행하세요.
echo ============================================================
exit /b 1


:error
set "EXIT_CODE=%ERRORLEVEL%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"

del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1
del /q "%RENDERED_MANIFEST_FILE%" >nul 2>&1

echo.
echo ============================================================
echo [ERROR] 배포 중 오류가 발생했습니다.
echo 종료 코드: %EXIT_CODE%
echo ============================================================
exit /b %EXIT_CODE%


:success
del /q "%SECRET_JSON_FILE%" >nul 2>&1
del /q "%DB_ENV_FILE%" >nul 2>&1
del /q "%RENDERED_MANIFEST_FILE%" >nul 2>&1
exit /b 0
