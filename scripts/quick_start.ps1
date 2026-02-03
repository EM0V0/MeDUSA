# MeDUSA Quick Start Script
# Author: Zhicheng Sun
#
# One-command setup: .\quick_start.ps1 -Mode dev
# Production: .\quick_start.ps1 -Mode prod

param(
    [ValidateSet("dev", "prod")]
    [string]$Mode = "dev",
    [string]$TestEmail = "test@medusa.local",
    [switch]$GenerateData,
    [switch]$RunFrontend
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MeDUSA Quick Start ($Mode mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check Python
try {
    python --version | Out-Null
    Write-Host "[OK] Python found" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python not found" -ForegroundColor Red
    exit 1
}

# Check Flutter
try {
    flutter --version | Out-Null
    Write-Host "[OK] Flutter found" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Flutter not found - frontend won't run" -ForegroundColor Yellow
}

if ($Mode -eq "dev") {
    # ==================== DEVELOPMENT MODE ====================
    Write-Host ""
    Write-Host "Starting DEVELOPMENT mode..." -ForegroundColor Yellow
    
    # Start local backend
    Write-Host ""
    Write-Host "Step 1: Starting local backend server..." -ForegroundColor Yellow
    
    $backendPath = Join-Path $ProjectRoot "backend\backend-py"
    
    # Check if requirements are installed
    Write-Host "  Installing Python dependencies..." -ForegroundColor Gray
    Push-Location $backendPath
    pip install -r requirements.txt -q
    
    # Start backend in background
    $backendJob = Start-Job -ScriptBlock {
        param($path)
        Set-Location $path
        $env:ENVIRONMENT = "development"
        $env:USE_MEMORY = "true"
        $env:JWT_SECRET = "dev-secret-for-local-testing-only-32chars"
        python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
    } -ArgumentList $backendPath
    
    Pop-Location
    
    Write-Host "  [OK] Backend starting at http://localhost:8000" -ForegroundColor Green
    Write-Host "       Waiting for server to be ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # Test health endpoint
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/admin/health" -TimeoutSec 10
        Write-Host "  [OK] Backend is healthy!" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Backend not responding yet, may need more time" -ForegroundColor Yellow
    }
    
    # Create test user
    Write-Host ""
    Write-Host "Step 2: Creating test user..." -ForegroundColor Yellow
    
    $body = @{
        email = $TestEmail
        password = "TestPass123!"
        role = "patient"
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/api/v1/auth/register" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body
        
        Write-Host "  [OK] Test user created: $($response.userId)" -ForegroundColor Green
        Write-Host "       Email: $TestEmail" -ForegroundColor Cyan
        Write-Host "       Password: TestPass123!" -ForegroundColor Cyan
    } catch {
        Write-Host "  [INFO] User may already exist" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Development Environment Ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backend API: http://localhost:8000" -ForegroundColor Cyan
    Write-Host "API Docs:    http://localhost:8000/docs" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test Credentials:" -ForegroundColor Yellow
    Write-Host "  Email:    $TestEmail" -ForegroundColor White
    Write-Host "  Password: TestPass123!" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop: Stop-Job $($backendJob.Id); Remove-Job $($backendJob.Id)" -ForegroundColor Gray
    
} else {
    # ==================== PRODUCTION MODE ====================
    Write-Host ""
    Write-Host "Starting PRODUCTION mode..." -ForegroundColor Yellow
    
    # Run AWS setup
    Write-Host ""
    Write-Host "Step 1: Setting up AWS resources..." -ForegroundColor Yellow
    $setupScript = Join-Path $PSScriptRoot "setup_aws.ps1"
    & $setupScript -DeployBackend
    
    # Get API URL
    $apiUrl = aws cloudformation describe-stacks `
        --stack-name medusa-api-v3-stack `
        --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" `
        --output text
    
    Write-Host ""
    Write-Host "Step 2: Updating frontend configuration..." -ForegroundColor Yellow
    
    $appConstantsPath = Join-Path $ProjectRoot "frontend\lib\core\constants\app_constants.dart"
    $content = Get-Content $appConstantsPath -Raw
    
    # Update API URLs
    $content = $content -replace "static const String _generalApiBaseUrl = '[^']+';", "static const String _generalApiBaseUrl = '$apiUrl';"
    $content = $content -replace "static const String _tremorApiBaseUrl = '[^']+';", "static const String _tremorApiBaseUrl = '$apiUrl';"
    
    Set-Content -Path $appConstantsPath -Value $content
    Write-Host "  [OK] Frontend configured with API: $apiUrl" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Production Environment Ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "API URL: $apiUrl" -ForegroundColor Cyan
}

# Generate test data if requested
if ($GenerateData) {
    Write-Host ""
    Write-Host "Generating test data..." -ForegroundColor Yellow
    
    $simulatorPath = Join-Path $ProjectRoot "tools\continuous_pi_simulator.py"
    
    # Get a patient ID (create one if needed)
    if ($Mode -eq "prod") {
        python $simulatorPath --create-test-user "patient@test.com" --generate-historical --days 3
    } else {
        Write-Host "  [INFO] Data generation skipped in dev mode (using in-memory storage)" -ForegroundColor Yellow
    }
}

# Run frontend if requested
if ($RunFrontend) {
    Write-Host ""
    Write-Host "Starting Flutter frontend..." -ForegroundColor Yellow
    
    $frontendPath = Join-Path $ProjectRoot "frontend"
    Push-Location $frontendPath
    
    flutter pub get
    flutter run -d chrome
    
    Pop-Location
}

Write-Host ""
Write-Host "Done! Enjoy MeDUSA!" -ForegroundColor Green
