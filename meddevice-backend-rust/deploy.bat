@echo off
REM Medical Device Backend Deployment Script - Zero Trust Architecture
REM Quick deployment to your AWS account

echo 🏥 Medical Device Backend - Zero Trust Architecture Deployment
echo =============================================================

REM Check required tools
where aws >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] AWS CLI not installed. Please install: winget install Amazon.AWSCLI
    pause
    exit /b 1
)

where sam >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] SAM CLI not installed. Please install: winget install Amazon.SAM-CLI
    pause
    exit /b 1
)

where cargo >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Rust Cargo not installed. Please install: winget install Rustlang.Rustup
    pause
    exit /b 1
)

REM Verify AWS credentials
echo [INFO] Verifying AWS credentials...
aws sts get-caller-identity >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] AWS credentials not configured. Please run: aws configure
    pause
    exit /b 1
)

REM Get AWS account information
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query "Account" --output text') do set AWS_ACCOUNT_ID=%%i
for /f "tokens=*" %%i in ('aws configure get region') do set AWS_REGION=%%i

echo [INFO] AWS Account: %AWS_ACCOUNT_ID%
echo [INFO] AWS Region: %AWS_REGION%

REM Select deployment environment
echo.
echo Select deployment environment:
echo 1. Development (development)
echo 2. Staging (staging) 
echo 3. Production (production)
echo.
set /p ENV_CHOICE="Please select (1-3): "

if "%ENV_CHOICE%"=="1" (
    set ENVIRONMENT=development
    set ENABLE_WAF=false
    set ENABLE_VPC=false
) else if "%ENV_CHOICE%"=="2" (
    set ENVIRONMENT=staging
    set ENABLE_WAF=true
    set ENABLE_VPC=false
) else if "%ENV_CHOICE%"=="3" (
    set ENVIRONMENT=production
    set ENABLE_WAF=true
    set ENABLE_VPC=true
) else (
    echo [ERROR] Invalid selection
    pause
    exit /b 1
)

echo [INFO] Deployment environment: %ENVIRONMENT%
echo [INFO] WAF protection: %ENABLE_WAF%
echo [INFO] VPC isolation: %ENABLE_VPC%

REM Generate medical-grade JWT secret (64-byte secure random)
echo.
echo [INFO] Generating medical-grade JWT secret (64 bytes)...
powershell -Command "Add-Type -AssemblyName System.Security; $bytes = New-Object byte[] 64; [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes); $key = [Convert]::ToBase64String($bytes); Write-Host 'JWT secret generated (please save):'; Write-Host $key -ForegroundColor Yellow; $key" > temp_jwt.txt
set /p JWT_SECRET=<temp_jwt.txt
del temp_jwt.txt

echo.
echo [SECURITY] Key features:
echo - Length: 88 characters (64-byte Base64 encoded)
echo - Algorithm: Cryptographically secure random generation
echo - Standard: Medical-grade security requirements

REM Build Lambda functions
echo.
echo [INFO] Building Lambda functions...

REM Check if cargo-lambda is installed
where cargo-lambda >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [INFO] Installing cargo-lambda...
    cargo install cargo-lambda
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to install cargo-lambda
        pause
        exit /b 1
    )
)

REM Build each Lambda function
echo [INFO] Building auth Lambda function...
cargo lambda build --release --bin auth
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build auth Lambda function
    pause
    exit /b 1
)

echo [INFO] Building patients Lambda function...
cargo lambda build --release --bin patients
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build patients Lambda function
    pause
    exit /b 1
)

echo [INFO] Building devices Lambda function...
cargo lambda build --release --bin devices
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build devices Lambda function
    pause
    exit /b 1
)

echo [INFO] Building reports Lambda function...
cargo lambda build --release --bin reports
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build reports Lambda function
    pause
    exit /b 1
)

echo [INFO] Building admin Lambda function...
cargo lambda build --release --bin admin
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build admin Lambda function
    pause
    exit /b 1
)

echo [SUCCESS] All Lambda functions built successfully!

REM Deploy to AWS
echo.
echo [INFO] Starting deployment to AWS...
echo [WARNING] This will create resources in your AWS account and may incur costs

set /p CONFIRM="Confirm deployment? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo [INFO] Deployment cancelled
    pause
    exit /b 0
)

REM Set stack name
set STACK_NAME=meddevice-backend-%ENVIRONMENT%

REM Check if first deployment
aws cloudformation describe-stacks --stack-name %STACK_NAME% >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo [INFO] Updating existing stack...
    sam deploy --config-env %ENVIRONMENT% ^
        --parameter-overrides ^
        Environment=%ENVIRONMENT% ^
        JWTSecret="%JWT_SECRET%" ^
        EnableWAF=%ENABLE_WAF% ^
        EnableVPC=%ENABLE_VPC% ^
        AllowedOrigins="*"
) else (
    echo [INFO] First deployment, using guided mode...
    sam deploy --guided ^
        --stack-name %STACK_NAME% ^
        --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND ^
        --parameter-overrides ^
        Environment=%ENVIRONMENT% ^
        JWTSecret="%JWT_SECRET%" ^
        EnableWAF=%ENABLE_WAF% ^
        EnableVPC=%ENABLE_VPC% ^
        AllowedOrigins="*" ^
        --config-env %ENVIRONMENT% ^
        --save-params
)

if %ERRORLEVEL% equ 0 (
    echo.
    echo ✅ Deployment completed successfully!
    echo.
    
    REM Get API endpoint
    for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey==`MedDeviceApiUrl`].OutputValue" --output text') do set API_URL=%%i
    
    echo 🌐 API endpoint: %API_URL%
    echo 🔑 JWT secret: %JWT_SECRET%
    echo 📊 Environment: %ENVIRONMENT%
    
    echo.
    echo 📋 Next steps:
    echo 1. Test API endpoints
    echo 2. Configure frontend application connection
    echo 3. Set up monitoring alerts
    echo 4. Perform security testing
    
    REM Test API
    echo.
    set /p TEST_API="Test API connection? (y/N): "
    if /i "%TEST_API%"=="y" (
        echo [INFO] Testing user registration endpoint...
        curl -X POST %API_URL%/auth/register ^
            -H "Content-Type: application/json" ^
            -d "{\"email\":\"test@example.com\",\"password\":\"TestPass123!\",\"first_name\":\"Test\",\"last_name\":\"User\",\"role\":\"Patient\"}"
    )
    
) else (
    echo.
    echo ❌ Deployment failed
    echo Please check error messages and retry
    
    REM Show common error solutions
    echo.
    echo 💡 Common issue solutions:
    echo - Insufficient permissions: Ensure AWS user has sufficient IAM permissions
    echo - Resource conflicts: Check if resources with same name exist
    echo - Quota limits: Check AWS service quotas
)

echo.
echo 📚 For more information see:
echo - Quick start guide: QUICK_START.md
echo - Project documentation: README.md

pause
