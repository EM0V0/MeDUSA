#!/usr/bin/env pwsh
# Deploy Enrichment Lambda Function for IoT Data
# This Lambda enriches raw IoT data with patient info and stores it in DynamoDB

param(
    [string]$FunctionName = "medusa-enrich-sensor-data",
    [string]$Region = "us-east-1",
    [string]$RoleName = "MedusaEnrichmentRole",
    [switch]$CreateRole,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Deploy Enrichment Lambda Function

Usage: .\deploy_enrichment_lambda.ps1 [options]

Options:
    -FunctionName <name>  Lambda function name (default: medusa-enrich-sensor-data)
    -Region <region>      AWS region (default: us-east-1)
    -RoleName <name>      IAM role name (default: MedusaEnrichmentRole)
    -CreateRole           Create IAM role if it doesn't exist
    -Help                 Show this help message
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Enrichment Lambda" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
try {
    $awsVersion = aws --version 2>&1
    Write-Host "✓ AWS CLI found: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS CLI not found." -ForegroundColor Red
    exit 1
}

# Create/Get IAM Role
if ($CreateRole) {
    Write-Host "[1/4] Configuring IAM Role..." -ForegroundColor Yellow
    
    # Check if role exists
    try {
        aws iam get-role --role-name $RoleName 2>&1 | Out-Null
        Write-Host "✓ Role $RoleName already exists" -ForegroundColor Green
    } catch {
        Write-Host "  Creating role $RoleName..." -ForegroundColor Gray
        
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

        aws iam create-role --role-name $RoleName --assume-role-policy-document $trustPolicy | Out-Null
        Write-Host "✓ Role created" -ForegroundColor Green
        
        # Attach policies
        aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
        
        Write-Host "✓ Policies attached (BasicExecution + DynamoDBFullAccess)" -ForegroundColor Green
        
        # Wait for propagation
        Write-Host "  Waiting for role propagation..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

# Get Account ID
$accountId = (aws sts get-caller-identity --query Account --output text)

# Package Lambda
Write-Host "[2/4] Packaging Lambda..." -ForegroundColor Yellow
$zipFile = "enrich_lambda.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile }

# Create temp directory for packaging
$tempDir = "temp_enrich_package"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy code
Copy-Item "enrich_code/lambda_function.py" -Destination $tempDir

# Zip it
Compress-Archive -Path "$tempDir/*" -DestinationPath $zipFile
Remove-Item $tempDir -Recurse -Force

Write-Host "✓ Lambda packaged to $zipFile" -ForegroundColor Green

# Deploy Lambda
Write-Host "[3/4] Deploying Lambda function..." -ForegroundColor Yellow

try {
    aws lambda get-function --function-name $FunctionName --region $Region 2>&1 | Out-Null
    
    Write-Host "  Updating existing function code..." -ForegroundColor Gray
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$zipFile" `
        --region $Region | Out-Null
        
    Write-Host "✓ Function code updated" -ForegroundColor Green
} catch {
    Write-Host "  Creating new function..." -ForegroundColor Gray
    
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.11 `
        --role "arn:aws:iam::${accountId}:role/${RoleName}" `
        --handler "lambda_function.lambda_handler" `
        --zip-file "fileb://$zipFile" `
        --timeout 30 `
        --memory-size 128 `
        --region $Region | Out-Null
        
    Write-Host "✓ Function created" -ForegroundColor Green
}

# Clean up
Remove-Item $zipFile
Write-Host "✓ Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "Function ARN: arn:aws:lambda:${Region}:${accountId}:function:${FunctionName}" -ForegroundColor Gray
