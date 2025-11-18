#!/usr/bin/env pwsh
# Complete deployment script for MeDUSA Tremor Monitoring System
# This script automates the entire deployment process

param(
    [string]$Region = "us-east-1",
    [switch]$SkipDynamoDB,
    [switch]$SkipLambda,
    [switch]$SkipAPI,
    [switch]$SkipTestData,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Complete MeDUSA Deployment Script

This script deploys the entire tremor monitoring backend:
1. DynamoDB tables (sensor-data, tremor-analysis)
2. Lambda functions (ProcessSensorData, QueryTremorData, GetTremorStatistics)
3. API Gateway REST API with two endpoints
4. Test data generation

Usage: .\deploy_complete.ps1 [options]

Options:
    -Region <region>    AWS region (default: us-east-1)
    -SkipDynamoDB       Skip DynamoDB table creation
    -SkipLambda         Skip Lambda deployment
    -SkipAPI            Skip API Gateway setup
    -SkipTestData       Skip test data generation
    -Help               Show this help message

Examples:
    .\deploy_complete.ps1
    .\deploy_complete.ps1 -SkipTestData
    .\deploy_complete.ps1 -Region us-west-2
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    MeDUSA Tremor Monitoring System - Complete Deployment    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Deployment Configuration:" -ForegroundColor Yellow
Write-Host "  Region: $Region" -ForegroundColor White
Write-Host "  Skip DynamoDB: $SkipDynamoDB" -ForegroundColor White
Write-Host "  Skip Lambda: $SkipLambda" -ForegroundColor White
Write-Host "  Skip API Gateway: $SkipAPI" -ForegroundColor White
Write-Host "  Skip Test Data: $SkipTestData" -ForegroundColor White
Write-Host ""

# Get AWS account info
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    $AccountId = $identity.Account
    Write-Host "AWS Account: $AccountId" -ForegroundColor Green
    Write-Host "Authenticated as: $($identity.Arn)" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "✗ AWS credentials not configured" -ForegroundColor Red
    Write-Host "  Run: aws configure" -ForegroundColor Yellow
    exit 1
}

# ============================================================================
# STEP 1: Create DynamoDB Tables
# ============================================================================

if (-not $SkipDynamoDB) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "STEP 1: Creating DynamoDB Tables" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""

    # Create sensor-data table
    Write-Host "[1/2] Creating medusa-sensor-data table..." -ForegroundColor Yellow
    try {
        aws dynamodb describe-table --table-name medusa-sensor-data --region $Region 2>&1 | Out-Null
        Write-Host "✓ Table already exists" -ForegroundColor Green
    } catch {
        Write-Host "  Creating new table..." -ForegroundColor Gray
        aws dynamodb create-table `
            --table-name medusa-sensor-data `
            --attribute-definitions `
                AttributeName=patient_id,AttributeType=S `
                AttributeName=timestamp,AttributeType=N `
            --key-schema `
                AttributeName=patient_id,KeyType=HASH `
                AttributeName=timestamp,KeyType=RANGE `
            --billing-mode PAY_PER_REQUEST `
            --region $Region | Out-Null
        
        Write-Host "✓ Table created" -ForegroundColor Green
    }

    # Create tremor-analysis table
    Write-Host "[2/2] Creating medusa-tremor-analysis table..." -ForegroundColor Yellow
    try {
        aws dynamodb describe-table --table-name medusa-tremor-analysis --region $Region 2>&1 | Out-Null
        Write-Host "✓ Table already exists" -ForegroundColor Green
    } catch {
        Write-Host "  Creating new table with GSI..." -ForegroundColor Gray
        aws dynamodb create-table `
            --table-name medusa-tremor-analysis `
            --attribute-definitions `
                AttributeName=patient_id,AttributeType=S `
                AttributeName=timestamp,AttributeType=N `
                AttributeName=device_id,AttributeType=S `
            --key-schema `
                AttributeName=patient_id,KeyType=HASH `
                AttributeName=timestamp,KeyType=RANGE `
            --global-secondary-indexes `
                "[{\"IndexName\":\"DeviceIndex\",\"KeySchema\":[{\"AttributeName\":\"device_id\",\"KeyType\":\"HASH\"},{\"AttributeName\":\"timestamp\",\"KeyType\":\"RANGE\"}],\"Projection\":{\"ProjectionType\":\"ALL\"}}]" `
            --billing-mode PAY_PER_REQUEST `
            --region $Region | Out-Null
        
        Write-Host "✓ Table created with DeviceIndex GSI" -ForegroundColor Green
        
        # Enable TTL
        Write-Host "  Enabling TTL..." -ForegroundColor Gray
        Start-Sleep -Seconds 5  # Wait for table to be active
        aws dynamodb update-time-to-live `
            --table-name medusa-tremor-analysis `
            --time-to-live-specification "Enabled=true,AttributeName=ttl" `
            --region $Region | Out-Null
        Write-Host "✓ TTL enabled (90 days auto-deletion)" -ForegroundColor Green
    }

    Write-Host ""
}

# ============================================================================
# STEP 2: Deploy Lambda Functions
# ============================================================================

if (-not $SkipLambda) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "STEP 2: Deploying Lambda Functions" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""

    # Deploy ProcessSensorData Lambda
    Write-Host "[1/3] Deploying ProcessSensorData Lambda..." -ForegroundColor Yellow
    & .\deploy.ps1 -Region $Region
    Write-Host ""

    # Deploy QueryTremorData Lambda
    Write-Host "[2/3] Deploying QueryTremorData Lambda..." -ForegroundColor Yellow
    & .\deploy_query_lambda.ps1 -Region $Region -CreateRole
    Write-Host ""

    # Deploy GetTremorStatistics Lambda
    Write-Host "[3/3] Deploying GetTremorStatistics Lambda..." -ForegroundColor Yellow
    & .\deploy_statistics_lambda.ps1 -Region $Region
    Write-Host ""
}

# ============================================================================
# STEP 3: Setup API Gateway
# ============================================================================

if (-not $SkipAPI) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "STEP 3: Setting up API Gateway" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""

    & .\setup_api_gateway.ps1 -Region $Region
    Write-Host ""
}

# ============================================================================
# STEP 4: Generate Test Data
# ============================================================================

if (-not $SkipTestData) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "STEP 4: Generating Test Data" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Do you want to generate test data? (y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "  Installing Python dependencies..." -ForegroundColor Gray
        pip install boto3 numpy scipy --quiet
        
        Write-Host "  Generating data for 1 patient (24 hours)..." -ForegroundColor Gray
        python generate_test_data.py --patients 1 --hours 24 --rate 12
        Write-Host ""
    } else {
        Write-Host "  Skipped test data generation" -ForegroundColor Gray
        Write-Host ""
    }
}

# ============================================================================
# STEP 5: Update Flutter App Configuration
# ============================================================================

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "STEP 5: Flutter App Configuration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if (Test-Path "api_endpoint.txt") {
    $ApiEndpoint = Get-Content "api_endpoint.txt" -Raw
    $ApiEndpoint = $ApiEndpoint.Trim()
    
    Write-Host "API Endpoint configured:" -ForegroundColor Green
    Write-Host "  $ApiEndpoint" -ForegroundColor Cyan
    Write-Host ""
    
    $appConstantsPath = "..\meddevice-app-flutter-main\lib\core\constants\app_constants.dart"
    
    if (Test-Path $appConstantsPath) {
        Write-Host "Update app_constants.dart with this endpoint:" -ForegroundColor Yellow
        Write-Host "  File: $appConstantsPath" -ForegroundColor Gray
        Write-Host "  Line: static const String _productionBaseUrl = '$ApiEndpoint';" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Do you want to auto-update app_constants.dart? (y/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            try {
                $content = Get-Content $appConstantsPath -Raw
                $content = $content -replace "static const String _productionBaseUrl = '[^']*';", "static const String _productionBaseUrl = '$ApiEndpoint';"
                $content | Set-Content $appConstantsPath -NoNewline
                Write-Host "✓ app_constants.dart updated successfully!" -ForegroundColor Green
                Write-Host ""
            } catch {
                Write-Host "✗ Failed to update automatically: $_" -ForegroundColor Red
                Write-Host "  Please update manually" -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
} else {
    Write-Host "⚠ API endpoint file not found" -ForegroundColor Yellow
    Write-Host "  API Gateway might not have been set up" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# Deployment Summary
# ============================================================================

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              🎉 Deployment Complete! 🎉                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "Deployed Components:" -ForegroundColor Yellow
Write-Host ""

if (-not $SkipDynamoDB) {
    Write-Host "  ✓ DynamoDB Tables:" -ForegroundColor Green
    Write-Host "    - medusa-sensor-data" -ForegroundColor White
    Write-Host "    - medusa-tremor-analysis" -ForegroundColor White
}

if (-not $SkipLambda) {
    Write-Host "  ✓ Lambda Functions:" -ForegroundColor Green
    Write-Host "    - ProcessSensorData" -ForegroundColor White
    Write-Host "    - QueryTremorData" -ForegroundColor White
    Write-Host "    - GetTremorStatistics" -ForegroundColor White
}

if (-not $SkipAPI) {
    Write-Host "  ✓ API Gateway:" -ForegroundColor Green
    if (Test-Path "api_endpoint.txt") {
        $endpoint = Get-Content "api_endpoint.txt" -Raw
        Write-Host "    Base URL: $($endpoint.Trim())" -ForegroundColor White
        Write-Host "    Endpoints:" -ForegroundColor Gray
        Write-Host "      - /api/v1/tremor/analysis (query data)" -ForegroundColor Gray
        Write-Host "      - /api/v1/tremor/statistics (aggregated stats)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Test the API endpoints:" -ForegroundColor White
if (Test-Path "api_endpoint.txt") {
    $endpoint = Get-Content "api_endpoint.txt" -Raw
    $endpoint = $endpoint.Trim()
    Write-Host "     # Query patient tremor data" -ForegroundColor Gray
    Write-Host "     curl '$endpoint/api/v1/tremor/analysis?patient_id=PAT-001&limit=5'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "     # Get aggregated statistics" -ForegroundColor Gray
    Write-Host "     curl '$endpoint/api/v1/tremor/statistics?patient_id=PAT-001'" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "  2. Run the Flutter app:" -ForegroundColor White
Write-Host "     cd ..\meddevice-app-flutter-main" -ForegroundColor Cyan
Write-Host "     flutter run -d windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Test pairing with Raspberry Pi:" -ForegroundColor White
Write-Host "     - Start Bluetooth advertising on Pi" -ForegroundColor Gray
Write-Host "     - Use Flutter app to scan and pair" -ForegroundColor Gray
Write-Host "     - Data will flow: Pi → AWS IoT → DynamoDB → Flutter" -ForegroundColor Gray
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  - Complete guide: DEPLOYMENT_CHECKLIST.md" -ForegroundColor White
Write-Host "  - Demo guide: TREMOR_DEMO_GUIDE.md" -ForegroundColor White
Write-Host "  - System guide: TREMOR_SYSTEM_GUIDE.md" -ForegroundColor White
Write-Host ""

exit 0
