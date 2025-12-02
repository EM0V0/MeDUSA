#!/usr/bin/env pwsh
# Deploy Query Lambda Function for Tremor Data API
# This Lambda queries processed tremor analysis data from DynamoDB

param(
    [string]$FunctionName = "QueryTremorData",
    [string]$Region = "us-east-1",
    [string]$RoleName = "MedusaLambdaRole",
    [switch]$CreateRole,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Deploy Query Lambda Function

Usage: .\deploy_query_lambda.ps1 [options]

Options:
    -FunctionName <name>  Lambda function name (default: QueryTremorData)
    -Region <region>      AWS region (default: us-east-1)
    -RoleName <name>      IAM role name (default: MedusaLambdaRole)
    -CreateRole           Create IAM role if it doesn't exist
    -Help                 Show this help message

Examples:
    .\deploy_query_lambda.ps1
    .\deploy_query_lambda.ps1 -CreateRole
    .\deploy_query_lambda.ps1 -Region us-west-2
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Query Tremor Data Lambda" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
Write-Host "[1/7] Checking AWS CLI..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>&1
    Write-Host "✓ AWS CLI found: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "  Download: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check AWS credentials
Write-Host "[2/7] Checking AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "✓ Authenticated as: $($identity.Arn)" -ForegroundColor Green
    $AccountId = $identity.Account
} catch {
    Write-Host "✗ AWS credentials not configured." -ForegroundColor Red
    Write-Host "  Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Create IAM role if needed
if ($CreateRole) {
    Write-Host "[3/7] Creating IAM role: $RoleName..." -ForegroundColor Yellow
    
    $trustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Service = "lambda.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        )
    } | ConvertTo-Json -Depth 10 -Compress
    
    try {
        aws iam create-role `
            --role-name $RoleName `
            --assume-role-policy-document $trustPolicy `
            --description "Role for MeDUSA Lambda functions" `
            --region $Region 2>&1 | Out-Null
        
        Write-Host "✓ Role created successfully" -ForegroundColor Green
        
        # Attach policies
        Write-Host "  Attaching policies..." -ForegroundColor Yellow
        
        aws iam attach-role-policy `
            --role-name $RoleName `
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" `
            --region $Region
        
        aws iam attach-role-policy `
            --role-name $RoleName `
            --policy-arn "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" `
            --region $Region
        
        Write-Host "✓ Policies attached" -ForegroundColor Green
        
        # Wait for role to propagate
        Write-Host "  Waiting for role to propagate (10 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
    } catch {
        if ($_.Exception.Message -match "EntityAlreadyExists") {
            Write-Host "✓ Role already exists" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to create role: $_" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "[3/7] Checking IAM role: $RoleName..." -ForegroundColor Yellow
    try {
        aws iam get-role --role-name $RoleName --region $Region 2>&1 | Out-Null
        Write-Host "✓ Role exists" -ForegroundColor Green
    } catch {
        Write-Host "✗ Role not found. Use -CreateRole to create it." -ForegroundColor Red
        exit 1
    }
}

# Create deployment package
Write-Host "[4/7] Creating deployment package..." -ForegroundColor Yellow

$packageDir = "query_package"
$zipFile = "query_tremor_data.zip"

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
Copy-Item "query_tremor_data.py" "$packageDir/"
Write-Host "✓ Copied query_tremor_data.py" -ForegroundColor Green

# Install dependencies (boto3 is included in Lambda runtime, so no need to package it)
Write-Host "  Note: boto3 is included in Lambda Python runtime" -ForegroundColor Gray

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
Write-Host "[5/7] Checking if function exists..." -ForegroundColor Yellow
$functionExists = $false
try {
    aws lambda get-function --function-name $FunctionName --region $Region 2>&1 | Out-Null
    $functionExists = $true
    Write-Host "✓ Function exists, will update" -ForegroundColor Green
} catch {
    Write-Host "✓ Function doesn't exist, will create" -ForegroundColor Green
}

# Deploy Lambda
Write-Host "[6/7] Deploying Lambda function..." -ForegroundColor Yellow

$roleArn = "arn:aws:iam::${AccountId}:role/$RoleName"

if ($functionExists) {
    # Update existing function
    Write-Host "  Updating function code..." -ForegroundColor Yellow
    
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$zipFile" `
        --region $Region | Out-Null
    
    Write-Host "✓ Function code updated" -ForegroundColor Green
    
    # Update configuration
    Write-Host "  Updating function configuration..." -ForegroundColor Yellow
    
    aws lambda update-function-configuration `
        --function-name $FunctionName `
        --runtime python3.11 `
        --handler query_tremor_data.lambda_handler `
        --timeout 30 `
        --memory-size 128 `
        --region $Region | Out-Null
    
    Write-Host "✓ Function configuration updated" -ForegroundColor Green
    
} else {
    # Create new function
    Write-Host "  Creating new function..." -ForegroundColor Yellow
    
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.11 `
        --role $roleArn `
        --handler query_tremor_data.lambda_handler `
        --zip-file "fileb://$zipFile" `
        --timeout 30 `
        --memory-size 128 `
        --description "Query tremor analysis data from DynamoDB for MeDUSA frontend" `
        --region $Region | Out-Null
    
    Write-Host "✓ Function created" -ForegroundColor Green
}

# Test Lambda
Write-Host "[7/7] Testing Lambda function..." -ForegroundColor Yellow

$testPayload = @{
    queryStringParameters = @{
        patient_id = "PAT-001"
        limit = 5
    }
} | ConvertTo-Json -Compress

$testPayload | Out-File -FilePath "test_payload.json" -Encoding utf8

try {
    aws lambda invoke `
        --function-name $FunctionName `
        --payload "file://test_payload.json" `
        --region $Region `
        response.json 2>&1 | Out-Null
    
    $response = Get-Content response.json | ConvertFrom-Json
    
    if ($response.statusCode -eq 200) {
        $body = $response.body | ConvertFrom-Json
        Write-Host "✓ Lambda test successful!" -ForegroundColor Green
        Write-Host "  Response: success=$($body.success), count=$($body.count)" -ForegroundColor Gray
    } else {
        Write-Host "⚠ Lambda returned status $($response.statusCode)" -ForegroundColor Yellow
        Write-Host "  Response: $($response.body)" -ForegroundColor Gray
    }
    
    # Clean up test files
    Remove-Item test_payload.json, response.json -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "⚠ Lambda test failed (this is OK if DynamoDB is empty)" -ForegroundColor Yellow
    Write-Host "  $_" -ForegroundColor Gray
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
Write-Host "  1. Create API Gateway to expose this Lambda" -ForegroundColor White
Write-Host "  2. Run: .\setup_api_gateway.ps1" -ForegroundColor Cyan
Write-Host "  3. Update Flutter app with API endpoint" -ForegroundColor White
Write-Host ""

# Clean up zip file
Remove-Item $zipFile -ErrorAction SilentlyContinue

exit 0
