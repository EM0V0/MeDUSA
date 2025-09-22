# Simple SAM Deployment Script for Medical Device Backend
# Usage: .\deploy.ps1 [development|staging|production]

param(
    [ValidateSet("development", "staging", "production")]
    [string]$Environment = "development"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Navigate to backend directory
$BackendDir = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path (Split-Path -Parent $BackendDir) "meddevice-backend-rust"

Write-Info "Deploying Medical Device Backend to $Environment environment..."
Write-Info "Backend directory: $BackendDir"

# Change to backend directory
Set-Location $BackendDir

# Check if SAM CLI is available
if (-not (Get-Command sam -ErrorAction SilentlyContinue)) {
    Write-Error "SAM CLI is not installed. Please install AWS SAM CLI first."
    exit 1
}

# Build the application
Write-Info "Building SAM application..."
sam build

if ($LASTEXITCODE -ne 0) {
    Write-Error "SAM build failed"
    exit 1
}

# Deploy the application
Write-Info "Deploying to AWS..."
$stackName = "meddevice-backend-$Environment"

sam deploy --stack-name $stackName --parameter-overrides Environment=$Environment --capabilities CAPABILITY_IAM --resolve-s3

if ($LASTEXITCODE -eq 0) {
    Write-Info "Deployment completed successfully!"
    Write-Info "Stack name: $stackName"
} else {
    Write-Error "Deployment failed"
    exit 1
}