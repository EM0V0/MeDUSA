#!/usr/bin/env pwsh
# Add doctor-patient management endpoints under /api/v1/doctor

param(
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Add Doctor Management Endpoints" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get account ID
Write-Host "[1/8] Getting AWS account info..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
$AccountId = $identity.Account
Write-Host "✓ Account ID: $AccountId" -ForegroundColor Green

# Find existing API
Write-Host "[2/8] Finding API Gateway..." -ForegroundColor Yellow
$apis = aws apigateway get-rest-apis --region $Region --output json | ConvertFrom-Json
$api = $apis.items | Where-Object { $_.name -eq "MeDUSA-Tremor-API" }

if (-not $api) {
    Write-Host "✗ MeDUSA-Tremor-API not found" -ForegroundColor Red
    exit 1
}

$ApiId = $api.id
Write-Host "✓ Found API: $ApiId" -ForegroundColor Green

# Get /api/v1 resource
Write-Host "[3/8] Getting /api/v1 resource..." -ForegroundColor Yellow
$resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region --output json | ConvertFrom-Json
$apiV1Resource = $resources.items | Where-Object { $_.path -eq "/api/v1" }

if (-not $apiV1Resource) {
    Write-Host "✗ /api/v1 resource not found" -ForegroundColor Red
    exit 1
}

$ApiV1ResourceId = $apiV1Resource.id
Write-Host "✓ /api/v1 resource: $ApiV1ResourceId" -ForegroundColor Green

# Create /api/v1/doctor resource
Write-Host "[4/8] Creating /api/v1/doctor resource..." -ForegroundColor Yellow
$doctorResource = $resources.items | Where-Object { $_.path -eq "/api/v1/doctor" }

if ($doctorResource) {
    $DoctorResourceId = $doctorResource.id
    Write-Host "⚠ /api/v1/doctor already exists: $DoctorResourceId" -ForegroundColor Yellow
} else {
    $doctorResult = aws apigateway create-resource `
        --rest-api-id $ApiId `
        --parent-id $ApiV1ResourceId `
        --path-part "doctor" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    $DoctorResourceId = $doctorResult.id
    Write-Host "✓ Created /api/v1/doctor: $DoctorResourceId" -ForegroundColor Green
}

# Refresh resources list
$resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region --output json | ConvertFrom-Json

# Create /api/v1/doctor/assign-patient resource
Write-Host "[5/8] Creating /api/v1/doctor/assign-patient resource..." -ForegroundColor Yellow
$assignResource = $resources.items | Where-Object { $_.path -eq "/api/v1/doctor/assign-patient" }

if ($assignResource) {
    Write-Host "⚠ /api/v1/doctor/assign-patient already exists" -ForegroundColor Yellow
    $AssignResourceId = $assignResource.id
} else {
    $assignResult = aws apigateway create-resource `
        --rest-api-id $ApiId `
        --parent-id $DoctorResourceId `
        --path-part "assign-patient" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    $AssignResourceId = $assignResult.id
    Write-Host "✓ Created /api/v1/doctor/assign-patient: $AssignResourceId" -ForegroundColor Green
}

# Create POST method for assign-patient
Write-Host "[6/8] Creating POST method for assign-patient..." -ForegroundColor Yellow

try {
    aws apigateway put-method `
        --rest-api-id $ApiId `
        --resource-id $AssignResourceId `
        --http-method POST `
        --authorization-type NONE `
        --region $Region | Out-Null
    
    # Enable CORS
    aws apigateway put-method-response `
        --rest-api-id $ApiId `
        --resource-id $AssignResourceId `
        --http-method POST `
        --status-code 200 `
        --response-parameters '{"method.response.header.Access-Control-Allow-Origin":true}' `
        --region $Region | Out-Null
    
    # Set up Lambda integration
    $assignLambdaArn = "arn:aws:lambda:${Region}:${AccountId}:function:AssignPatientToDoctor"
    $integrationUri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/${assignLambdaArn}/invocations"
    
    aws apigateway put-integration `
        --rest-api-id $ApiId `
        --resource-id $AssignResourceId `
        --http-method POST `
        --type AWS_PROXY `
        --integration-http-method POST `
        --uri $integrationUri `
        --region $Region | Out-Null
    
    # Grant API Gateway permission to invoke Lambda
    try {
        aws lambda add-permission `
            --function-name AssignPatientToDoctor `
            --statement-id "apigateway-assign-patient-prod" `
            --action lambda:InvokeFunction `
            --principal apigateway.amazonaws.com `
            --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/POST/api/v1/doctor/assign-patient" `
            --region $Region 2>$null | Out-Null
    } catch {
        Write-Host "  Permission may already exist" -ForegroundColor Gray
    }
    
    Write-Host "✓ POST /api/v1/doctor/assign-patient configured" -ForegroundColor Green
} catch {
    Write-Host "⚠ Method may already exist" -ForegroundColor Yellow
}

# Refresh resources
$resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region --output json | ConvertFrom-Json

# Create /api/v1/doctor/patients resource
Write-Host "[7/8] Creating /api/v1/doctor/patients resource..." -ForegroundColor Yellow
$patientsResource = $resources.items | Where-Object { $_.path -eq "/api/v1/doctor/patients" }

if ($patientsResource) {
    Write-Host "⚠ /api/v1/doctor/patients already exists" -ForegroundColor Yellow
    $PatientsResourceId = $patientsResource.id
} else {
    $patientsResult = aws apigateway create-resource `
        --rest-api-id $ApiId `
        --parent-id $DoctorResourceId `
        --path-part "patients" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    $PatientsResourceId = $patientsResult.id
    Write-Host "✓ Created /api/v1/doctor/patients: $PatientsResourceId" -ForegroundColor Green
}

# Create GET method for patients
Write-Host "[8/8] Creating GET method for patients..." -ForegroundColor Yellow

try {
    aws apigateway put-method `
        --rest-api-id $ApiId `
        --resource-id $PatientsResourceId `
        --http-method GET `
        --authorization-type NONE `
        --request-parameters 'method.request.querystring.doctor_id=true' `
        --region $Region | Out-Null
    
    # Enable CORS
    aws apigateway put-method-response `
        --rest-api-id $ApiId `
        --resource-id $PatientsResourceId `
        --http-method GET `
        --status-code 200 `
        --response-parameters '{"method.response.header.Access-Control-Allow-Origin":true}' `
        --region $Region | Out-Null
    
    # Set up Lambda integration
    $patientsLambdaArn = "arn:aws:lambda:${Region}:${AccountId}:function:GetDoctorPatients"
    $integrationUri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/${patientsLambdaArn}/invocations"
    
    aws apigateway put-integration `
        --rest-api-id $ApiId `
        --resource-id $PatientsResourceId `
        --http-method GET `
        --type AWS_PROXY `
        --integration-http-method POST `
        --uri $integrationUri `
        --region $Region | Out-Null
    
    # Grant API Gateway permission to invoke Lambda
    try {
        aws lambda add-permission `
            --function-name GetDoctorPatients `
            --statement-id "apigateway-get-patients-prod" `
            --action lambda:InvokeFunction `
            --principal apigateway.amazonaws.com `
            --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/GET/api/v1/doctor/patients" `
            --region $Region 2>$null | Out-Null
    } catch {
        Write-Host "  Permission may already exist" -ForegroundColor Gray
    }
    
    Write-Host "✓ GET /api/v1/doctor/patients configured" -ForegroundColor Green
} catch {
    Write-Host "⚠ Method may already exist" -ForegroundColor Yellow
}

# Deploy API
Write-Host ""
Write-Host "Deploying API to Prod stage..." -ForegroundColor Yellow
aws apigateway create-deployment `
    --rest-api-id $ApiId `
    --stage-name Prod `
    --description "Add doctor management endpoints" `
    --region $Region | Out-Null

Write-Host "✓ API deployed" -ForegroundColor Green

# Get API URL
$apiUrl = "https://${ApiId}.execute-api.${Region}.amazonaws.com/Prod"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "API Endpoints:" -ForegroundColor Cyan
Write-Host "  POST ${apiUrl}/api/v1/doctor/assign-patient" -ForegroundColor White
Write-Host "    Body: { ""doctor_id"": ""usr_xxx"", ""patient_email"": ""email@example.com"" }" -ForegroundColor Gray
Write-Host ""
Write-Host "  GET  ${apiUrl}/api/v1/doctor/patients?doctor_id=usr_xxx" -ForegroundColor White
Write-Host ""
Write-Host "Test command:" -ForegroundColor Cyan
Write-Host '  curl -X POST "https://buektgcf8l.execute-api.us-east-1.amazonaws.com/Prod/api/v1/doctor/assign-patient" \' -ForegroundColor Gray
Write-Host '    -H "Content-Type: application/json" \' -ForegroundColor Gray
Write-Host '    -d "{\"doctor_id\":\"usr_10b28691\",\"patient_email\":\"kdu9@jh.edu\"}"' -ForegroundColor Gray
Write-Host ""
