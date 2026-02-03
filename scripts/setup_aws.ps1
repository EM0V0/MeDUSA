# MeDUSA AWS Setup Script
# Author: Zhicheng Sun
# 
# This script sets up all required AWS resources for MeDUSA
# Run with: .\setup_aws.ps1

param(
    [string]$Region = "us-east-1",
    [string]$JwtSecret = "",
    [string]$SenderEmail = "medusa000012@gmail.com",
    [switch]$SkipSecrets,
    [switch]$SkipTables,
    [switch]$DeployBackend
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MeDUSA AWS Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
try {
    aws --version | Out-Null
    Write-Host "[OK] AWS CLI is installed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Check AWS credentials
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "[OK] AWS credentials configured: $($identity.Account)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] AWS credentials not configured. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# Step 1: Create JWT Secret
if (-not $SkipSecrets) {
    Write-Host ""
    Write-Host "Step 1: Creating JWT Secret..." -ForegroundColor Yellow
    
    if ([string]::IsNullOrEmpty($JwtSecret)) {
        # Generate random 64-character secret
        $JwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object { [char]$_ })
    }
    
    try {
        $secretJson = @{ secret = $JwtSecret } | ConvertTo-Json -Compress
        aws secretsmanager create-secret `
            --name medusa/jwt `
            --secret-string $secretJson `
            --region $Region 2>$null
        Write-Host "[OK] JWT Secret created in Secrets Manager" -ForegroundColor Green
    } catch {
        Write-Host "[INFO] JWT Secret may already exist, attempting update..." -ForegroundColor Yellow
        $secretJson = @{ secret = $JwtSecret } | ConvertTo-Json -Compress
        aws secretsmanager update-secret `
            --secret-id medusa/jwt `
            --secret-string $secretJson `
            --region $Region
        Write-Host "[OK] JWT Secret updated" -ForegroundColor Green
    }
}

# Step 2: Create additional DynamoDB tables
if (-not $SkipTables) {
    Write-Host ""
    Write-Host "Step 2: Creating DynamoDB Tables..." -ForegroundColor Yellow
    
    # medusa-sensor-data table
    Write-Host "  Creating medusa-sensor-data..." -ForegroundColor Gray
    try {
        aws dynamodb create-table `
            --table-name medusa-sensor-data `
            --attribute-definitions `
                AttributeName=device_id,AttributeType=S `
                AttributeName=timestamp,AttributeType=N `
            --key-schema `
                AttributeName=device_id,KeyType=HASH `
                AttributeName=timestamp,KeyType=RANGE `
            --billing-mode PAY_PER_REQUEST `
            --stream-specification StreamEnabled=true,StreamViewType=NEW_IMAGE `
            --sse-specification Enabled=true `
            --tags Key=Project,Value=MeDUSA `
            --region $Region 2>$null
        Write-Host "  [OK] medusa-sensor-data created" -ForegroundColor Green
    } catch {
        Write-Host "  [INFO] medusa-sensor-data already exists" -ForegroundColor Yellow
    }
    
    # medusa-tremor-analysis table
    Write-Host "  Creating medusa-tremor-analysis..." -ForegroundColor Gray
    try {
        aws dynamodb create-table `
            --table-name medusa-tremor-analysis `
            --attribute-definitions `
                AttributeName=patient_id,AttributeType=S `
                AttributeName=timestamp,AttributeType=S `
            --key-schema `
                AttributeName=patient_id,KeyType=HASH `
                AttributeName=timestamp,KeyType=RANGE `
            --billing-mode PAY_PER_REQUEST `
            --sse-specification Enabled=true `
            --tags Key=Project,Value=MeDUSA `
            --region $Region 2>$null
        Write-Host "  [OK] medusa-tremor-analysis created" -ForegroundColor Green
    } catch {
        Write-Host "  [INFO] medusa-tremor-analysis already exists" -ForegroundColor Yellow
    }
    
    # Enable TTL on tables
    Write-Host "  Enabling TTL on tables..." -ForegroundColor Gray
    aws dynamodb update-time-to-live `
        --table-name medusa-sensor-data `
        --time-to-live-specification Enabled=true,AttributeName=ttl `
        --region $Region 2>$null
    
    aws dynamodb update-time-to-live `
        --table-name medusa-tremor-analysis `
        --time-to-live-specification Enabled=true,AttributeName=ttl `
        --region $Region 2>$null
    
    Write-Host "  [OK] TTL enabled" -ForegroundColor Green
}

# Step 3: Verify SES email
Write-Host ""
Write-Host "Step 3: Verifying SES Email..." -ForegroundColor Yellow
try {
    aws ses verify-email-identity --email-address $SenderEmail --region $Region 2>$null
    Write-Host "[OK] Verification email sent to $SenderEmail" -ForegroundColor Green
    Write-Host "     Please check your email and click the verification link!" -ForegroundColor Yellow
} catch {
    Write-Host "[INFO] Email may already be verified" -ForegroundColor Yellow
}

# Step 4: Deploy backend
if ($DeployBackend) {
    Write-Host ""
    Write-Host "Step 4: Deploying Backend..." -ForegroundColor Yellow
    
    Push-Location (Join-Path $PSScriptRoot "..\backend")
    
    Write-Host "  Building SAM application..." -ForegroundColor Gray
    sam build
    
    Write-Host "  Deploying to AWS..." -ForegroundColor Gray
    sam deploy --stack-name medusa-api-v3-stack --region $Region --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset
    
    # Get API URL
    $apiUrl = aws cloudformation describe-stacks `
        --stack-name medusa-api-v3-stack `
        --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" `
        --output text `
        --region $Region
    
    Pop-Location
    
    Write-Host ""
    Write-Host "[OK] Backend deployed!" -ForegroundColor Green
    Write-Host "     API URL: $apiUrl" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify your email in SES (check inbox)" -ForegroundColor White
Write-Host "2. Deploy backend: cd backend && sam build && sam deploy" -ForegroundColor White
Write-Host "3. Update frontend API URL in app_constants.dart" -ForegroundColor White
Write-Host "4. Run simulator: python tools/continuous_pi_simulator.py" -ForegroundColor White
Write-Host ""
