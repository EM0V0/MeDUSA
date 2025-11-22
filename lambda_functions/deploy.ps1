# PowerShell Deployment Script for MeDUSA Lambda Functions
# Usage: .\deploy.ps1 [-FunctionName medusa-process-sensor-data]

param(
    [string]$FunctionName = "medusa-process-sensor-data",
    [string]$Region = $(if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }),
    [string]$RoleArn = $env:LAMBDA_ROLE_ARN
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "MeDUSA Lambda Deployment Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Function: $FunctionName"
Write-Host "Region:   $Region"
Write-Host ""

# Check AWS credentials
try {
    aws sts get-caller-identity *>$null
} catch {
    Write-Host "❌ Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run: aws configure"
    exit 1
}

# Check if IAM role is set
if ([string]::IsNullOrEmpty($RoleArn)) {
    Write-Host "⚠ Warning: LAMBDA_ROLE_ARN not set" -ForegroundColor Yellow
    Write-Host "Please set it or create a role with DynamoDB permissions:"
    Write-Host "`$env:LAMBDA_ROLE_ARN = 'arn:aws:iam::ACCOUNT_ID:role/medusa-lambda-role'"
    exit 1
}

Write-Host "Step 1: Creating deployment package..." -ForegroundColor Green

# Clean up previous builds
Remove-Item -Path package -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path process_sensor_data.zip -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path package -Force | Out-Null

# Install dependencies
Write-Host "Installing dependencies (Linux binaries)..."
# Exclude boto3 as it is in the runtime
pip install --platform manylinux2014_x86_64 --target package/ --implementation cp --python-version 3.10 --only-binary=:all: --upgrade numpy scipy

# Copy Lambda function
Copy-Item process_sensor_data.py package/

# Create ZIP using PowerShell
Write-Host "Creating ZIP archive..."
Compress-Archive -Path package\* -DestinationPath process_sensor_data.zip -Force
Write-Host "✓ Deployment package created: process_sensor_data.zip" -ForegroundColor Green

# Upload to S3
$BucketName = "medusa-deploy-artifacts-charlotte"
$S3Key = "lambda/process_sensor_data.zip"
Write-Host "Uploading to S3 ($BucketName)..."
aws s3 cp process_sensor_data.zip "s3://$BucketName/$S3Key"

# Check if function exists
Write-Host ""
Write-Host "Step 2: Checking if Lambda function exists..." -ForegroundColor Green
try {
    aws lambda get-function --function-name $FunctionName --region $Region 2>$null | Out-Null
    $functionExists = $true
} catch {
    $functionExists = $false
}

if ($functionExists) {
    Write-Host "✓ Function exists, updating code..." -ForegroundColor Green
    aws lambda update-function-code `
        --function-name $FunctionName `
        --s3-bucket $BucketName `
        --s3-key $S3Key `
        --region $Region `
        --output json | Out-Null
    Write-Host "✓ Function code updated" -ForegroundColor Green
} else {
    Write-Host "Function does not exist, creating new function..." -ForegroundColor Yellow
    
    aws lambda create-function `
        --function-name $FunctionName `
        --runtime python3.10 `
        --role $RoleArn `
        --handler process_sensor_data.lambda_handler `
        --code "S3Bucket=$BucketName,S3Key=$S3Key" `
        --timeout 60 `
        --memory-size 512 `
        --region $Region `
        --output json | Out-Null
    Write-Host "✓ Function created" -ForegroundColor Green
}

# Update configuration
Write-Host ""
Write-Host "Step 3: Updating function configuration..." -ForegroundColor Green

aws lambda update-function-configuration `
    --function-name $FunctionName `
    --runtime python3.10 `
    --timeout 60 `
    --memory-size 512 `
    --region $Region `
    --output json | Out-Null
Write-Host "✓ Configuration updated" -ForegroundColor Green

# Test function
Write-Host ""
Write-Host "Step 4: Testing function..." -ForegroundColor Green

$testEvent = @{
    device_id = "test_device_001"
    patient_id = "test_patient_123"
    window_size = 100
    sampling_rate = 100
} | ConvertTo-Json

Write-Host "Test event:"
Write-Host $testEvent
Write-Host ""

$testEvent | Out-File -FilePath test_event.json -Encoding utf8

aws lambda invoke `
    --function-name $FunctionName `
    --payload file://test_event.json `
    --region $Region `
    response.json 2>$null | Out-Null

if (Test-Path response.json) {
    Write-Host "Lambda response:"
    Get-Content response.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
    Write-Host ""
}

# Cleanup
Remove-Item -Path test_event.json -Force -ErrorAction SilentlyContinue
Remove-Item -Path response.json -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

$functionArn = aws lambda get-function --function-name $FunctionName --region $Region --query 'Configuration.FunctionArn' --output text
Write-Host "Function ARN: $functionArn"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Create DynamoDB table: medusa-tremor-analysis"
Write-Host "2. Grant Lambda permissions to read medusa-sensor-data"
Write-Host "3. Set up EventBridge trigger for periodic processing"
Write-Host ""
