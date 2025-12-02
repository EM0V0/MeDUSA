#!/usr/bin/env pwsh
# Deploy both doctor-patient management Lambda functions

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Doctor-Patient Management Lambdas" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Check AWS CLI
Write-Host "[1/3] Checking AWS credentials..." -ForegroundColor Yellow
$awsIdentity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ AWS CLI not configured or credentials expired" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Authenticated" -ForegroundColor Green

# Deploy assign_patient_to_doctor
Write-Host ""
Write-Host "[2/3] Deploying assign_patient_to_doctor Lambda..." -ForegroundColor Yellow

# Create deployment package
$zipFile = "assign_patient_to_doctor.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile }

Compress-Archive -Path "assign_patient_to_doctor.py" -DestinationPath $zipFile
Write-Host "✓ Package created: $zipFile" -ForegroundColor Green

# Check if function exists
$functionName = "AssignPatientToDoctor"
try {
    aws lambda get-function --function-name $functionName 2>&1 | Out-Null
    $exists = $true
} catch {
    $exists = $false
}

if ($exists) {
    Write-Host "  Updating existing function..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $functionName `
        --zip-file fileb://$zipFile | Out-Null
} else {
    Write-Host "  Creating new function..." -ForegroundColor Yellow
    aws lambda create-function `
        --function-name $functionName `
        --runtime python3.9 `
        --role arn:aws:iam::636750015010:role/MedusaLambdaRole `
        --handler assign_patient_to_doctor.lambda_handler `
        --zip-file fileb://$zipFile `
        --timeout 30 `
        --memory-size 256 | Out-Null
}
Write-Host "✓ $functionName deployed" -ForegroundColor Green

# Deploy get_doctor_patients
Write-Host ""
Write-Host "[3/3] Deploying get_doctor_patients Lambda..." -ForegroundColor Yellow

# Create deployment package
$zipFile2 = "get_doctor_patients.zip"
if (Test-Path $zipFile2) { Remove-Item $zipFile2 }

Compress-Archive -Path "get_doctor_patients.py" -DestinationPath $zipFile2
Write-Host "✓ Package created: $zipFile2" -ForegroundColor Green

# Check if function exists
$functionName2 = "GetDoctorPatients"
try {
    aws lambda get-function --function-name $functionName2 2>&1 | Out-Null
    $exists2 = $true
} catch {
    $exists2 = $false
}

if ($exists2) {
    Write-Host "  Updating existing function..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $functionName2 `
        --zip-file fileb://$zipFile2 | Out-Null
} else {
    Write-Host "  Creating new function..." -ForegroundColor Yellow
    aws lambda create-function `
        --function-name $functionName2 `
        --runtime python3.9 `
        --role arn:aws:iam::636750015010:role/MedusaLambdaRole `
        --handler get_doctor_patients.lambda_handler `
        --zip-file fileb://$zipFile2 `
        --timeout 30 `
        --memory-size 256 | Out-Null
}
Write-Host "✓ $functionName2 deployed" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Add API Gateway endpoints:" -ForegroundColor White
Write-Host "     POST /api/v1/doctor/assign-patient -> AssignPatientToDoctor" -ForegroundColor White
Write-Host "     GET /api/v1/doctor/patients -> GetDoctorPatients" -ForegroundColor White
Write-Host "  2. Test the endpoints" -ForegroundColor White
Write-Host ""
