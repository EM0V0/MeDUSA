# Deploy MeDUSA API v3
# Usage: .\deploy_medusa_api_v3.ps1

$FunctionName = "medusa-api-v3"
$Region = "us-east-1"
$BucketName = "medusa-deploy-artifacts-charlotte"
$S3Key = "lambda/medusa-api-v3.zip"

Write-Host "Deploying $FunctionName..." -ForegroundColor Cyan

# 1. Create ZIP
Write-Host "Creating ZIP archive..."
if (Test-Path medusa-api-v3.zip) { Remove-Item medusa-api-v3.zip }

# Zip the content of medusa-api-v3 folder
Compress-Archive -Path medusa-api-v3\* -DestinationPath medusa-api-v3.zip -Force

# 2. Update Lambda Code (Direct Upload)
Write-Host "Updating Lambda function code (Direct Upload)..."
aws lambda update-function-code `
    --function-name $FunctionName `
    --zip-file fileb://medusa-api-v3.zip `
    --region $Region `
    --output json | Out-Null

Write-Host "✓ API Deployment Complete!" -ForegroundColor Green
