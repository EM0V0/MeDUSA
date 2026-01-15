# MeDUSA Backend - Local Development Server Startup Script
# This script sets up and runs the backend locally for development and testing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MeDUSA Backend - Local Dev Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is installed
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python detected: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python not found. Please install Python 3.12+" -ForegroundColor Red
    exit 1
}

# Check if virtual environment exists
if (-not (Test-Path ".venv")) {
    Write-Host ""
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
    Write-Host "✓ Virtual environment created" -ForegroundColor Green
}

# Activate virtual environment
Write-Host ""
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& .\.venv\Scripts\Activate.ps1

# Install/upgrade dependencies
Write-Host ""
Write-Host "Installing dependencies..." -ForegroundColor Yellow
python -m pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
Write-Host "✓ Dependencies installed" -ForegroundColor Green

# Set environment variables for local development
Write-Host ""
Write-Host "Setting environment variables..." -ForegroundColor Yellow
$env:USE_MEMORY = "true"
$env:JWT_SECRET = "dev-secret-key-please-change-in-production"
$env:REFRESH_TTL_SECONDS = "604800"    # 7 days
$env:JWT_EXPIRE_SECONDS = "3600"       # 1 hour
Write-Host "✓ Environment configured" -ForegroundColor Green

# Display configuration
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  - Mode: In-Memory Database (no AWS required)" -ForegroundColor White
Write-Host "  - Server: http://localhost:8080" -ForegroundColor White
Write-Host "  - API Docs: http://localhost:8080/docs" -ForegroundColor White
Write-Host "  - ReDoc: http://localhost:8080/redoc" -ForegroundColor White
Write-Host "  - JWT Expiry: 1 hour" -ForegroundColor White
Write-Host "  - Refresh Token Expiry: 7 days" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting server..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Start the server
uvicorn main:app --reload --port 8080 --host 0.0.0.0

