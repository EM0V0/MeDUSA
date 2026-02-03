# MeDUSA Fresh AWS Setup Script
# Author: Zhicheng Sun
#
# This script:
# 1. Clears old AWS credentials
# 2. Configures new AWS account
# 3. Creates all required resources from scratch
# 4. Deploys the backend
# 5. Creates test accounts
#
# Usage: .\fresh_setup.ps1

param(
    [string]$Region = "us-east-1",
    [string]$SenderEmail = "",
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MeDUSA Fresh AWS Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Check current credentials
Write-Host "Step 0: Checking current AWS credentials..." -ForegroundColor Yellow
try {
    $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    Write-Host "  Current account: $($identity.Account)" -ForegroundColor Gray
    Write-Host "  Current user: $($identity.Arn)" -ForegroundColor Gray
} catch {
    Write-Host "  No credentials configured" -ForegroundColor Gray
}

# Step 1: Clear and reconfigure AWS credentials
Write-Host ""
Write-Host "Step 1: Configure NEW AWS credentials" -ForegroundColor Yellow
Write-Host "  Please enter your NEW AWS account credentials:" -ForegroundColor White
Write-Host ""

# Interactive credential setup
aws configure

# Verify new credentials
Write-Host ""
Write-Host "Verifying new credentials..." -ForegroundColor Gray
try {
    $newIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "[OK] New account configured: $($newIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to verify credentials. Please run 'aws configure' manually." -ForegroundColor Red
    exit 1
}

# Step 2: Create JWT Secret
Write-Host ""
Write-Host "Step 2: Creating JWT Secret in Secrets Manager..." -ForegroundColor Yellow

$jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object { [char]$_ })
$secretJson = "{`"secret`":`"$jwtSecret`"}"

try {
    aws secretsmanager create-secret `
        --name medusa/jwt `
        --secret-string $secretJson `
        --region $Region 2>$null
    Write-Host "[OK] JWT Secret created" -ForegroundColor Green
} catch {
    Write-Host "[INFO] Secret may exist, updating..." -ForegroundColor Yellow
    aws secretsmanager put-secret-value `
        --secret-id medusa/jwt `
        --secret-string $secretJson `
        --region $Region 2>$null
    Write-Host "[OK] JWT Secret updated" -ForegroundColor Green
}

# Step 3: Create DynamoDB Tables
Write-Host ""
Write-Host "Step 3: Creating DynamoDB Tables..." -ForegroundColor Yellow

# Table definitions
$tables = @(
    @{
        Name = "medusa-sensor-data"
        PK = "device_id"
        PKType = "S"
        SK = "timestamp"
        SKType = "N"
        Stream = $true
    },
    @{
        Name = "medusa-tremor-analysis"
        PK = "patient_id"
        PKType = "S"
        SK = "timestamp"
        SKType = "S"
        Stream = $false
    }
)

foreach ($table in $tables) {
    Write-Host "  Creating $($table.Name)..." -ForegroundColor Gray
    
    $keySchema = "[{`"AttributeName`":`"$($table.PK)`",`"KeyType`":`"HASH`"}"
    $attrDef = "[{`"AttributeName`":`"$($table.PK)`",`"AttributeType`":`"$($table.PKType)`"}"
    
    if ($table.SK) {
        $keySchema += ",{`"AttributeName`":`"$($table.SK)`",`"KeyType`":`"RANGE`"}"
        $attrDef += ",{`"AttributeName`":`"$($table.SK)`",`"AttributeType`":`"$($table.SKType)`"}"
    }
    $keySchema += "]"
    $attrDef += "]"
    
    try {
        $cmd = "aws dynamodb create-table --table-name $($table.Name) --attribute-definitions '$attrDef' --key-schema '$keySchema' --billing-mode PAY_PER_REQUEST --sse-specification Enabled=true --region $Region"
        
        if ($table.Stream) {
            $cmd += " --stream-specification StreamEnabled=true,StreamViewType=NEW_IMAGE"
        }
        
        Invoke-Expression $cmd 2>$null
        Write-Host "  [OK] $($table.Name) created" -ForegroundColor Green
    } catch {
        Write-Host "  [INFO] $($table.Name) may already exist" -ForegroundColor Yellow
    }
}

# Enable TTL
Write-Host "  Enabling TTL..." -ForegroundColor Gray
aws dynamodb update-time-to-live --table-name medusa-sensor-data --time-to-live-specification "Enabled=true,AttributeName=ttl" --region $Region 2>$null
aws dynamodb update-time-to-live --table-name medusa-tremor-analysis --time-to-live-specification "Enabled=true,AttributeName=ttl" --region $Region 2>$null
Write-Host "  [OK] TTL enabled" -ForegroundColor Green

# Step 4: Setup SES
Write-Host ""
Write-Host "Step 4: Setting up AWS SES for email..." -ForegroundColor Yellow

if ([string]::IsNullOrEmpty($SenderEmail)) {
    $SenderEmail = Read-Host "Enter email address to verify for SES (e.g., your@gmail.com)"
}

if (-not [string]::IsNullOrEmpty($SenderEmail)) {
    aws ses verify-email-identity --email-address $SenderEmail --region $Region 2>$null
    Write-Host "[OK] Verification email sent to $SenderEmail" -ForegroundColor Green
    Write-Host "     IMPORTANT: Check your email and click the verification link!" -ForegroundColor Yellow
}

# Step 5: Deploy Backend
if (-not $SkipDeploy) {
    Write-Host ""
    Write-Host "Step 5: Deploying Backend with SAM..." -ForegroundColor Yellow
    
    Push-Location (Join-Path $ProjectRoot "backend")
    
    Write-Host "  Building..." -ForegroundColor Gray
    sam build
    
    Write-Host "  Deploying..." -ForegroundColor Gray
    sam deploy --stack-name medusa-api-v3-stack --region $Region --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset
    
    # Get outputs
    Write-Host ""
    Write-Host "  Getting deployment outputs..." -ForegroundColor Gray
    $apiUrl = aws cloudformation describe-stacks --stack-name medusa-api-v3-stack --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text --region $Region
    
    Pop-Location
    
    Write-Host "[OK] Backend deployed!" -ForegroundColor Green
    Write-Host "     API URL: $apiUrl" -ForegroundColor Cyan
    
    # Update frontend config
    Write-Host ""
    Write-Host "Step 6: Updating frontend configuration..." -ForegroundColor Yellow
    
    $appConstantsPath = Join-Path $ProjectRoot "frontend\lib\core\constants\app_constants.dart"
    $content = Get-Content $appConstantsPath -Raw
    
    # Remove trailing slash if present
    $apiUrlClean = $apiUrl.TrimEnd('/')
    
    $content = $content -replace "static const String _generalApiBaseUrl = '[^']+';", "static const String _generalApiBaseUrl = '$apiUrlClean';"
    $content = $content -replace "static const String _tremorApiBaseUrl = '[^']+';", "static const String _tremorApiBaseUrl = '$apiUrlClean';"
    
    Set-Content -Path $appConstantsPath -Value $content
    Write-Host "[OK] Frontend API URL updated" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Step 5: Skipping deployment (--SkipDeploy)" -ForegroundColor Yellow
}

# Step 6: Create Test Users
Write-Host ""
Write-Host "Step 7: Creating test users..." -ForegroundColor Yellow

if (-not $SkipDeploy) {
    # Wait for API to be ready
    Write-Host "  Waiting for API to be ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Test health
    try {
        $health = Invoke-RestMethod -Uri "$apiUrl/api/v1/admin/health" -TimeoutSec 10
        Write-Host "  [OK] API is healthy" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] API not responding yet, continuing anyway..." -ForegroundColor Yellow
    }
    
    # Create test users
    $testUsers = @(
        @{ email = "patient@medusa.test"; password = "TestPass123!"; role = "patient" },
        @{ email = "doctor@medusa.test"; password = "TestPass123!"; role = "doctor" }
    )
    
    foreach ($user in $testUsers) {
        try {
            $body = $user | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "$apiUrl/api/v1/auth/register" `
                -Method POST `
                -ContentType "application/json" `
                -Body $body
            
            Write-Host "  [OK] Created: $($user.email) ($($user.role))" -ForegroundColor Green
        } catch {
            Write-Host "  [INFO] $($user.email) may already exist" -ForegroundColor Yellow
        }
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "AWS Account: $($newIdentity.Account)" -ForegroundColor White
Write-Host ""
Write-Host "Test Accounts Created:" -ForegroundColor Yellow
Write-Host "  Patient: patient@medusa.test / TestPass123!" -ForegroundColor White
Write-Host "  Doctor:  doctor@medusa.test / TestPass123!" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify your email in SES (check inbox)" -ForegroundColor White
Write-Host "  2. Run frontend: cd frontend && flutter run" -ForegroundColor White
Write-Host "  3. Generate test data: python tools\continuous_pi_simulator.py" -ForegroundColor White
Write-Host ""
