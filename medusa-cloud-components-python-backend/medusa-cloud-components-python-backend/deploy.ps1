# MeDUSA AWS Lambda Deployment Script
# This script deploys the API v3 compliant backend to AWS Lambda

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$StackName = "medusa-api-v3-stack",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTest = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MeDUSA AWS Lambda Deployment" -ForegroundColor Cyan
Write-Host "  API v3 - 100% Tested Locally" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
Write-Host "[INFO] Checking AWS CLI..." -ForegroundColor Blue
try {
    $awsVersion = aws --version 2>&1
    Write-Host "[OK] AWS CLI: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS CLI not found. Please install AWS CLI first." -ForegroundColor Red
    Write-Host "Download: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check AWS SAM CLI
Write-Host "[INFO] Checking AWS SAM CLI..." -ForegroundColor Blue
try {
    $samVersion = sam --version 2>&1
    Write-Host "[OK] SAM CLI: $samVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] SAM CLI not found. Please install SAM CLI first." -ForegroundColor Red
    Write-Host "Download: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html" -ForegroundColor Yellow
    exit 1
}

# Check AWS credentials
Write-Host "[INFO] Checking AWS credentials..." -ForegroundColor Blue
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-Host "[OK] AWS Account: $($identity.Account)" -ForegroundColor Green
    Write-Host "[OK] AWS User: $($identity.Arn)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS credentials not configured." -ForegroundColor Red
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Step 1: Create/Update JWT Secret in Secrets Manager
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 1: JWT Secret Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$secretName = "medusa/jwt"
Write-Host "[INFO] Checking for existing secret: $secretName" -ForegroundColor Blue

try {
    $existingSecret = aws secretsmanager describe-secret --secret-id $secretName --region $Region 2>&1 | ConvertFrom-Json
    Write-Host "[OK] Secret already exists: $secretName" -ForegroundColor Green
    
    $updateResponse = Read-Host "Do you want to update the JWT secret? (y/N)"
    if ($updateResponse -eq "y" -or $updateResponse -eq "Y") {
        $jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
        $secretValue = "{`"secret`":`"$jwtSecret`"}"
        aws secretsmanager update-secret --secret-id $secretName --secret-string $secretValue --region $Region | Out-Null
        Write-Host "[OK] JWT secret updated" -ForegroundColor Green
    }
} catch {
    Write-Host "[INFO] Creating new JWT secret..." -ForegroundColor Blue
    $jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
    $secretValue = "{`"secret`":`"$jwtSecret`"}"
    aws secretsmanager create-secret --name $secretName --secret-string $secretValue --region $Region --description "MeDUSA JWT Secret" | Out-Null
    Write-Host "[OK] JWT secret created" -ForegroundColor Green
}

# Step 2: Build
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Step 2: Building Application" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "[INFO] Running SAM build..." -ForegroundColor Blue
    sam build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Build completed successfully" -ForegroundColor Green
}

# Step 3: Deploy
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 3: Deploying to AWS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "[INFO] Deploying stack: $StackName to region: $Region" -ForegroundColor Blue
sam deploy --stack-name $StackName --region $Region --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Deployment failed!" -ForegroundColor Red
    exit 1
}

# Step 4: Get outputs
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 4: Deployment Information" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "[INFO] Retrieving stack outputs..." -ForegroundColor Blue
$outputs = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs" | ConvertFrom-Json

$apiUrl = ($outputs | Where-Object { $_.OutputKey -eq "ApiUrl" }).OutputValue

Write-Host ""
Write-Host "[OK] Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "API Endpoint: $apiUrl" -ForegroundColor Yellow
Write-Host "Swagger UI: ${apiUrl}docs" -ForegroundColor Yellow
Write-Host ""

# Save API URL for testing
$apiUrl | Out-File -FilePath "api_url.txt" -Encoding UTF8
Write-Host "[INFO] API URL saved to api_url.txt" -ForegroundColor Blue

# Step 5: Test deployment
if (-not $SkipTest) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Step 5: Testing Deployed API" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $testResponse = Read-Host "Do you want to run API tests now? (Y/n)"
    if ($testResponse -ne "n" -and $testResponse -ne "N") {
        Write-Host "[INFO] Waiting 10 seconds for API to be ready..." -ForegroundColor Blue
        Start-Sleep -Seconds 10
        
        Write-Host "[INFO] Running cloud tests..." -ForegroundColor Blue
        cd backend-py
        python test_api.py $apiUrl
        cd ..
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Stack Name: $StackName" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "API Endpoint: $apiUrl" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test API: python backend-py\test_api.py $apiUrl" -ForegroundColor White
Write-Host "2. View Logs: sam logs -n MedusaAPIFunction --stack-name $StackName --tail" -ForegroundColor White
Write-Host "3. Monitor: AWS CloudWatch Console" -ForegroundColor White
Write-Host "4. Update Frontend: Set API_BASE_URL to $apiUrl" -ForegroundColor White
Write-Host ""

