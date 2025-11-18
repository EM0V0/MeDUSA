#!/usr/bin/env pwsh
# Deploy Statistics Lambda Function
# Provides aggregated tremor statistics for patients

param(
    [string]$FunctionName = "GetTremorStatistics",
    [string]$Region = "us-east-1",
    [string]$RoleName = "MedusaLambdaRole",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Deploy Statistics Lambda Function

Usage: .\deploy_statistics_lambda.ps1 [options]

Options:
    -FunctionName <name>  Lambda function name (default: GetTremorStatistics)
    -Region <region>      AWS region (default: us-east-1)
    -RoleName <name>      IAM role name (default: MedusaLambdaRole)
    -Help                 Show this help message

Examples:
    .\deploy_statistics_lambda.ps1
    .\deploy_statistics_lambda.ps1 -Region us-west-2
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Tremor Statistics Lambda" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS credentials
Write-Host "[1/5] Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "✓ Authenticated as: $($identity.Arn)" -ForegroundColor Green
    $AccountId = $identity.Account
} catch {
    Write-Host "✗ AWS credentials not configured" -ForegroundColor Red
    exit 1
}

# Check if role exists
Write-Host "[2/5] Checking IAM role: $RoleName..." -ForegroundColor Yellow
try {
    aws iam get-role --role-name $RoleName --region $Region 2>&1 | Out-Null
    Write-Host "✓ Role exists" -ForegroundColor Green
} catch {
    Write-Host "✗ Role not found. Please run deploy_query_lambda.ps1 -CreateRole first" -ForegroundColor Red
    exit 1
}

# Create deployment package
Write-Host "[3/5] Creating deployment package..." -ForegroundColor Yellow

$packageDir = "stats_package"
$zipFile = "get_tremor_statistics.zip"

# Clean up old package
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
if (Test-Path $zipFile) {
    Remove-Item -Force $zipFile
}

# Create package directory
New-Item -ItemType Directory -Path $packageDir | Out-Null

# Copy Lambda function
Copy-Item "get_tremor_statistics.py" "$packageDir/"
Write-Host "✓ Copied get_tremor_statistics.py" -ForegroundColor Green

# Create zip file
Write-Host "  Creating ZIP archive..." -ForegroundColor Yellow
Push-Location $packageDir
Compress-Archive -Path * -DestinationPath "..\$zipFile" -Force
Pop-Location

# Clean up package directory
Remove-Item -Recurse -Force $packageDir

$zipSize = (Get-Item $zipFile).Length / 1KB
Write-Host "✓ Package created: $zipFile ($([math]::Round($zipSize, 2)) KB)" -ForegroundColor Green

# Check if function exists
Write-Host "[4/5] Checking if function exists..." -ForegroundColor Yellow
$functionExists = $false
try {
    aws lambda get-function --function-name $FunctionName --region $Region 2>&1 | Out-Null
    $functionExists = $true
    Write-Host "✓ Function exists, will update" -ForegroundColor Green
} catch {
    Write-Host "✓ Function doesn't exist, will create" -ForegroundColor Green
}

# Deploy Lambda
Write-Host "[5/5] Deploying Lambda function..." -ForegroundColor Yellow

$roleArn = "arn:aws:iam::${AccountId}:role/$RoleName"

if ($functionExists) {
    # Update existing function
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$zipFile" `
        --region $Region | Out-Null
    
    Write-Host "✓ Function code updated" -ForegroundColor Green
    
    aws lambda update-function-configuration `
        --function-name $FunctionName `
        --runtime python3.11 `
        --handler get_tremor_statistics.lambda_handler `
        --timeout 30 `
        --memory-size 256 `
        --region $Region | Out-Null
    
    Write-Host "✓ Function configuration updated" -ForegroundColor Green
    
} else {
    # Create new function
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.11 `
        --role $roleArn `
        --handler get_tremor_statistics.lambda_handler `
        --zip-file "fileb://$zipFile" `
        --timeout 30 `
        --memory-size 256 `
        --description "Calculate aggregated tremor statistics for MeDUSA patients" `
        --region $Region | Out-Null
    
    Write-Host "✓ Function created" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Function Name: $FunctionName" -ForegroundColor White
Write-Host "Region:        $Region" -ForegroundColor White
Write-Host "ARN:           arn:aws:lambda:${Region}:${AccountId}:function:$FunctionName" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Add /api/v1/tremor/statistics endpoint to API Gateway" -ForegroundColor White
Write-Host "  2. Test: curl 'https://API_ID.../api/v1/tremor/statistics?patient_id=PAT-001'" -ForegroundColor Cyan
Write-Host ""

# Clean up zip file
Remove-Item $zipFile -ErrorAction SilentlyContinue

exit 0
