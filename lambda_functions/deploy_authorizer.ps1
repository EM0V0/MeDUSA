#!/usr/bin/env pwsh
# Deploy Authorizer Lambda Function
# This Lambda validates JWT tokens for API Gateway

param(
    [string]$FunctionName = "MedusaAuthorizer",
    [string]$Region = "us-east-1",
    [string]$RoleName = "MedusaLambdaRole",
    [string]$JwtSecret = "dev-secret",
    [switch]$CreateRole,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Deploy Authorizer Lambda Function

Usage: .\deploy_authorizer.ps1 [options]

Options:
    -FunctionName <name>  Lambda function name (default: MedusaAuthorizer)
    -Region <region>      AWS region (default: us-east-1)
    -RoleName <name>      IAM role name (default: MedusaLambdaRole)
    -JwtSecret <secret>   JWT Secret Key (default: dev-secret)
    -CreateRole           Create IAM role if it doesn't exist
    -Help                 Show this help message
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Authorizer Lambda" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get account ID
Write-Host "[1/6] Getting AWS account info..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
$AccountId = $identity.Account
Write-Host "✓ Account ID: $AccountId" -ForegroundColor Green

# Create/Get IAM Role
Write-Host "[2/6] Checking IAM Role..." -ForegroundColor Yellow
try {
    $role = aws iam get-role --role-name $RoleName --output json | ConvertFrom-Json
    $RoleArn = $role.Role.Arn
    Write-Host "✓ Role found: $RoleArn" -ForegroundColor Green
} catch {
    if ($CreateRole) {
        Write-Host "  Creating role '$RoleName'..." -ForegroundColor Yellow
        # Trust policy for Lambda
        $trustPolicy = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Principal = @{ Service = "lambda.amazonaws.com" }
                    Action = "sts:AssumeRole"
                }
            )
        } | ConvertTo-Json -Depth 10
        
        $role = aws iam create-role --role-name $RoleName --assume-role-policy-document $trustPolicy --output json | ConvertFrom-Json
        $RoleArn = $role.Role.Arn
        
        # Attach basic execution policy
        aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        
        Write-Host "✓ Role created: $RoleArn" -ForegroundColor Green
        Write-Host "  Waiting 10s for role propagation..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    } else {
        Write-Host "✗ Role not found: $RoleName" -ForegroundColor Red
        Write-Host "  Use -CreateRole to create it automatically." -ForegroundColor Yellow
        exit 1
    }
}

# Prepare deployment package
Write-Host "[3/6] Preparing deployment package..." -ForegroundColor Yellow
$PackageDir = "authorizer_package"
if (Test-Path $PackageDir) { Remove-Item -Recurse -Force $PackageDir }
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Copy source file
Copy-Item "authorizer.py" -Destination "$PackageDir/lambda_function.py"

# Install dependencies
Write-Host "  Installing dependencies (PyJWT)..." -ForegroundColor Gray
pip install PyJWT -t $PackageDir --quiet

# Create ZIP
$ZipFile = "authorizer.zip"
if (Test-Path $ZipFile) { Remove-Item -Force $ZipFile }
Write-Host "  Zipping package..." -ForegroundColor Gray
Compress-Archive -Path "$PackageDir/*" -DestinationPath $ZipFile

Write-Host "✓ Package created: $ZipFile" -ForegroundColor Green

# Deploy Lambda
Write-Host "[4/6] Deploying Lambda function..." -ForegroundColor Yellow

# Check if function exists
$functionExists = $false
try {
    aws lambda get-function --function-name $FunctionName --region $Region --output json | Out-Null
    $functionExists = $true
} catch {
    $functionExists = $false
}

if ($functionExists) {
    Write-Host "  Updating existing function code..." -ForegroundColor Gray
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$ZipFile" `
        --region $Region `
        --output json | Out-Null
        
    Write-Host "  Updating configuration..." -ForegroundColor Gray
    aws lambda update-function-configuration `
        --function-name $FunctionName `
        --environment "Variables={JWT_SECRET=$JwtSecret}" `
        --region $Region `
        --output json | Out-Null
} else {
    Write-Host "  Creating new function..." -ForegroundColor Gray
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.9 `
        --role $RoleArn `
        --handler lambda_function.lambda_handler `
        --zip-file "fileb://$ZipFile" `
        --environment "Variables={JWT_SECRET=$JwtSecret}" `
        --region $Region `
        --output json | Out-Null
}

Write-Host "✓ Lambda deployed successfully" -ForegroundColor Green

# Clean up
Write-Host "[5/6] Cleaning up..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $PackageDir
Remove-Item -Force $ZipFile
Write-Host "✓ Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Authorizer Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Function Name: $FunctionName" -ForegroundColor White
Write-Host "Region:        $Region" -ForegroundColor White
Write-Host ""
