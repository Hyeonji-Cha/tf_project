@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "INFRA_DIR=%ROOT_DIR%\infra"
if not defined APP_NAMESPACE set "APP_NAMESPACE=de-ai-18-cha"

echo.
echo ============================================================
echo [1/3] Terraform output을 읽습니다.
echo ============================================================
call :terraform_output AWS_REGION aws_region
call :terraform_output CLUSTER_NAME cluster_name

if defined AWS_REGION if defined CLUSTER_NAME (
    echo.
    echo ============================================================
    echo [2/3] Kubernetes Namespace를 먼저 삭제합니다.
    echo ============================================================
    aws eks update-kubeconfig --region "%AWS_REGION%" --name "%CLUSTER_NAME%"
    kubectl delete namespace "%APP_NAMESPACE%" ^
      --ignore-not-found=true ^
      --wait=true ^
      --timeout=20m
)

echo.
echo ============================================================
echo [3/3] Terraform 리소스를 삭제합니다.
echo ============================================================
terraform -chdir="%INFRA_DIR%" destroy -auto-approve
if errorlevel 1 goto :error

echo.
echo ============================================================
echo 전체 삭제 완료
echo ============================================================
exit /b 0

:terraform_output
set "%~1="
pushd "%INFRA_DIR%" >nul 2>&1
if errorlevel 1 exit /b 1
for /f "usebackq delims=" %%A in (`terraform output -raw %~2 2^>nul`) do set "%~1=%%A"
popd >nul
exit /b 0

:error
echo.
echo ============================================================
echo [ERROR] 삭제 중 오류가 발생했습니다.
echo Kubernetes가 만든 ALB 또는 ECR 이미지가 남아 있는지 확인하세요.
echo ============================================================
exit /b 1
