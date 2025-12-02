# Deploy MeDUSA Backend to AWS Lambda
# PowerShell deployment script

Write-Host "🚀 Deploying MeDUSA Backend to AWS..." -ForegroundColor Cyan
Write-Host ""

# Check if SAM CLI is installed
if (-not (Get-Command sam -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: SAM CLI not found" -ForegroundColor Red
    Write-Host "Please install SAM CLI first: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html" -ForegroundColor Yellow
    exit 1
}

# Check if AWS credentials are configured
try {
    $awsAccount = aws sts get-caller-identity --query Account --output text 2>$null
    if (-not $awsAccount) {
        throw "No AWS credentials"
    }
    Write-Host "✅ AWS Account: $awsAccount" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run 'aws configure' to set up your credentials" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🧹 Cleaning previous build..." -ForegroundColor Cyan
if (Test-Path ".aws-sam") { Remove-Item -Recurse -Force ".aws-sam" }

Write-Host "📦 Building SAM application..." -ForegroundColor Cyan
sam build --use-container

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🚀 Deploying to AWS..." -ForegroundColor Cyan
# Use non-interactive deploy if config exists
if (Test-Path "samconfig.toml") {
    sam deploy --no-confirm-changeset --no-fail-on-empty-changeset
} else {
    sam deploy --guided
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Copy the API Gateway URL from the output above" -ForegroundColor Yellow
    Write-Host "  2. Update Flutter app's network_service.dart with the new API URL" -ForegroundColor Yellow
    Write-Host "  3. Test the reset password functionality" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}
