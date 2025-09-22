@echo off
REM Simple AWS Deployment Script for Medical Device Backend
REM This script provides a streamlined deployment process

echo 🏥 Medical Device Backend - Simple AWS Deployment
echo ================================================

REM Check if AWS CLI is installed
where aws >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] AWS CLI not installed. Please install: winget install Amazon.AWSCLI
    echo [INFO] After installation, run: aws configure
    pause
    exit /b 1
)

REM Check if SAM CLI is installed
where sam >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] SAM CLI not installed. Please install: winget install Amazon.SAM-CLI
    pause
    exit /b 1
)

REM Check AWS credentials
echo [INFO] Checking AWS credentials...
aws sts get-caller-identity >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] AWS credentials not configured.
    echo [INFO] Please run: aws configure
    echo [INFO] You will need:
    echo   - AWS Access Key ID
    echo   - AWS Secret Access Key
    echo   - Default region (e.g., us-east-1)
    echo   - Default output format (json)
    pause
    exit /b 1
)

REM Get AWS account info
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query "Account" --output text') do set AWS_ACCOUNT_ID=%%i
for /f "tokens=*" %%i in ('aws configure get region') do set AWS_REGION=%%i

echo [SUCCESS] AWS credentials verified
echo [INFO] Account: %AWS_ACCOUNT_ID%
echo [INFO] Region: %AWS_REGION%

REM Select environment
echo.
echo Select deployment environment:
echo 1. Development (cheap, no WAF/VPC)
echo 2. Production (secure, with WAF/VPC)
echo.
set /p ENV_CHOICE="Choose (1-2): "

if "%ENV_CHOICE%"=="1" (
    set ENVIRONMENT=development
    set ENABLE_WAF=false
    set ENABLE_VPC=false
    echo [INFO] Selected: Development environment
) else if "%ENV_CHOICE%"=="2" (
    set ENVIRONMENT=production
    set ENABLE_WAF=true
    set ENABLE_VPC=true
    echo [INFO] Selected: Production environment
) else (
    echo [ERROR] Invalid selection
    pause
    exit /b 1
)

REM Generate JWT secret
echo.
echo [INFO] Generating secure JWT secret...
powershell -Command "Add-Type -AssemblyName System.Security; $bytes = New-Object byte[] 64; [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes); [Convert]::ToBase64String($bytes)" > temp_jwt.txt
set /p JWT_SECRET=<temp_jwt.txt
del temp_jwt.txt

echo [SUCCESS] JWT secret generated (saved for later use)

REM Install cargo-lambda if needed
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

REM Build Lambda functions
echo.
echo [INFO] Building Lambda functions...
echo [INFO] This may take a few minutes...

cargo lambda build --release --bin auth
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build auth function
    pause
    exit /b 1
)

cargo lambda build --release --bin patients
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build patients function
    pause
    exit /b 1
)

cargo lambda build --release --bin devices
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build devices function
    pause
    exit /b 1
)

cargo lambda build --release --bin reports
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build reports function
    pause
    exit /b 1
)

cargo lambda build --release --bin admin
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to build admin function
    pause
    exit /b 1
)

echo [SUCCESS] All Lambda functions built successfully!

REM Deploy to AWS
echo.
echo [INFO] Deploying to AWS...
echo [WARNING] This will create AWS resources and may incur costs
echo [INFO] Estimated monthly cost for %ENVIRONMENT%: $5-50
echo.

set /p CONFIRM="Continue with deployment? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo [INFO] Deployment cancelled
    pause
    exit /b 0
)

set STACK_NAME=meddevice-backend-%ENVIRONMENT%

echo [INFO] Deploying stack: %STACK_NAME%
echo [INFO] This may take 5-10 minutes...

sam deploy --guided ^
    --stack-name %STACK_NAME% ^
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND ^
    --parameter-overrides ^
    Environment=%ENVIRONMENT% ^
    JWTSecret="%JWT_SECRET%" ^
    EnableWAF=%ENABLE_WAF% ^
    EnableVPC=%ENABLE_VPC% ^
    AllowedOrigins="*" ^
    --save-params

if %ERRORLEVEL% equ 0 (
    echo.
    echo ✅ DEPLOYMENT SUCCESSFUL!
    echo.
    
    REM Get API URL
    for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --query "Stacks[0].Outputs[?OutputKey==`MedDeviceApiUrl`].OutputValue" --output text') do set API_URL=%%i
    
    echo 🌐 API Endpoint: %API_URL%
    echo 🔑 JWT Secret: %JWT_SECRET%
    echo 📊 Environment: %ENVIRONMENT%
    echo.
    
    echo 📋 Next Steps:
    echo 1. Update your Flutter app with the API URL above
    echo 2. Test the API endpoints
    echo 3. Monitor costs in AWS Console
    echo.
    
    echo 🧪 Test API:
    echo curl %API_URL%/health
    echo.
    
    set /p TEST_API="Test API now? (y/N): "
    if /i "%TEST_API%"=="y" (
        echo [INFO] Testing API...
        curl -s %API_URL%/health
        echo.
    )
    
) else (
    echo.
    echo ❌ DEPLOYMENT FAILED
    echo.
    echo 💡 Common solutions:
    echo - Check AWS permissions
    echo - Verify region settings
    echo - Check for resource conflicts
    echo - Review CloudFormation events in AWS Console
)

echo.
echo 📚 For more help, see: AWS_DEPLOYMENT.md
pause
