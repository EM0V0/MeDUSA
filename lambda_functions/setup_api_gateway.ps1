#!/usr/bin/env pwsh
# Setup API Gateway for MeDUSA Tremor Monitoring System
# Creates REST API and connects to Lambda functions

param(
    [string]$ApiName = "MeDUSA-Tremor-API",
    [string]$QueryLambdaName = "QueryTremorData",
    [string]$StatsLambdaName = "GetTremorStatistics",
    [string]$StageName = "Prod",
    [string]$Region = "us-east-1",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Setup API Gateway for MeDUSA

Usage: .\setup_api_gateway.ps1 [options]

Options:
    -ApiName <name>           API name (default: MeDUSA-Tremor-API)
    -QueryLambdaName <name>   Query Lambda function (default: QueryTremorData)
    -StatsLambdaName <name>   Statistics Lambda function (default: GetTremorStatistics)
    -StageName <stage>        Deployment stage (default: Prod)
    -Region <region>          AWS region (default: us-east-1)
    -Help                     Show this help message

Examples:
    .\setup_api_gateway.ps1
    .\setup_api_gateway.ps1 -StageName dev
"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup API Gateway for MeDUSA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get account ID
Write-Host "[1/12] Getting AWS account info..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
$AccountId = $identity.Account
Write-Host "✓ Account ID: $AccountId" -ForegroundColor Green

# Check if Lambda functions exist
Write-Host "[2/12] Checking Lambda functions..." -ForegroundColor Yellow
try {
    $queryLambdaInfo = aws lambda get-function --function-name $QueryLambdaName --region $Region --output json | ConvertFrom-Json
    $QueryLambdaArn = $queryLambdaInfo.Configuration.FunctionArn
    Write-Host "✓ Query Lambda found: $QueryLambdaArn" -ForegroundColor Green
} catch {
    Write-Host "✗ Query Lambda not found: $QueryLambdaName" -ForegroundColor Red
    Write-Host "  Please deploy Lambda first: .\deploy_query_lambda.ps1" -ForegroundColor Yellow
    exit 1
}

try {
    $statsLambdaInfo = aws lambda get-function --function-name $StatsLambdaName --region $Region --output json | ConvertFrom-Json
    $StatsLambdaArn = $statsLambdaInfo.Configuration.FunctionArn
    Write-Host "✓ Statistics Lambda found: $StatsLambdaArn" -ForegroundColor Green
} catch {
    Write-Host "✗ Statistics Lambda not found: $StatsLambdaName" -ForegroundColor Red
    Write-Host "  Please deploy Lambda first: .\deploy_statistics_lambda.ps1" -ForegroundColor Yellow
    exit 1
}

# Check if API already exists
Write-Host "[3/12] Checking for existing API..." -ForegroundColor Yellow
$existingApis = aws apigateway get-rest-apis --region $Region --output json | ConvertFrom-Json
$existingApi = $existingApis.items | Where-Object { $_.name -eq $ApiName }

if ($existingApi) {
    Write-Host "⚠ API already exists: $($existingApi.id)" -ForegroundColor Yellow
    Write-Host "  Do you want to delete and recreate? (y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "  Deleting existing API..." -ForegroundColor Yellow
        aws apigateway delete-rest-api --rest-api-id $existingApi.id --region $Region
        Write-Host "✓ Deleted existing API" -ForegroundColor Green
    } else {
        Write-Host "✗ Aborted" -ForegroundColor Red
        exit 1
    }
}

# Create REST API
Write-Host "[4/12] Creating REST API..." -ForegroundColor Yellow
$apiResult = aws apigateway create-rest-api `
    --name $ApiName `
    --description "REST API for MeDUSA tremor monitoring system" `
    --endpoint-configuration types=REGIONAL `
    --region $Region `
    --output json | ConvertFrom-Json

$ApiId = $apiResult.id
Write-Host "✓ API created: $ApiId" -ForegroundColor Green

# Get root resource ID
Write-Host "[5/12] Getting root resource..." -ForegroundColor Yellow
$resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region --output json | ConvertFrom-Json
$RootId = $resources.items[0].id
Write-Host "✓ Root resource ID: $RootId" -ForegroundColor Green

# Create /api resource
Write-Host "[6/12] Creating resource structure..." -ForegroundColor Yellow
Write-Host "  Creating /api..." -ForegroundColor Gray
$apiResource = aws apigateway create-resource `
    --rest-api-id $ApiId `
    --parent-id $RootId `
    --path-part "api" `
    --region $Region `
    --output json | ConvertFrom-Json
$ApiResourceId = $apiResource.id

Write-Host "  Creating /api/v1..." -ForegroundColor Gray
$v1Resource = aws apigateway create-resource `
    --rest-api-id $ApiId `
    --parent-id $ApiResourceId `
    --path-part "v1" `
    --region $Region `
    --output json | ConvertFrom-Json
$V1ResourceId = $v1Resource.id

Write-Host "  Creating /api/v1/tremor..." -ForegroundColor Gray
$tremorResource = aws apigateway create-resource `
    --rest-api-id $ApiId `
    --parent-id $V1ResourceId `
    --path-part "tremor" `
    --region $Region `
    --output json | ConvertFrom-Json
$TremorResourceId = $tremorResource.id

Write-Host "  Creating /api/v1/tremor/analysis..." -ForegroundColor Gray
$analysisResource = aws apigateway create-resource `
    --rest-api-id $ApiId `
    --parent-id $TremorResourceId `
    --path-part "analysis" `
    --region $Region `
    --output json | ConvertFrom-Json
$AnalysisResourceId = $analysisResource.id

Write-Host "  Creating /api/v1/tremor/statistics..." -ForegroundColor Gray
$statisticsResource = aws apigateway create-resource `
    --rest-api-id $ApiId `
    --parent-id $TremorResourceId `
    --path-part "statistics" `
    --region $Region `
    --output json | ConvertFrom-Json
$StatisticsResourceId = $statisticsResource.id

Write-Host "✓ Resource structure created" -ForegroundColor Green

# Create GET method for /analysis endpoint
Write-Host "[7/12] Creating GET method for /analysis..." -ForegroundColor Yellow
aws apigateway put-method `
    --rest-api-id $ApiId `
    --resource-id $AnalysisResourceId `
    --http-method GET `
    --authorization-type NONE `
    --request-parameters "method.request.querystring.patient_id=true,method.request.querystring.device_id=false,method.request.querystring.start_time=false,method.request.querystring.end_time=false,method.request.querystring.limit=false" `
    --region $Region | Out-Null

Write-Host "✓ GET method for /analysis created" -ForegroundColor Green

# Create GET method for /statistics endpoint
Write-Host "[8/12] Creating GET method for /statistics..." -ForegroundColor Yellow
aws apigateway put-method `
    --rest-api-id $ApiId `
    --resource-id $StatisticsResourceId `
    --http-method GET `
    --authorization-type NONE `
    --request-parameters "method.request.querystring.patient_id=true,method.request.querystring.start_time=false,method.request.querystring.end_time=false" `
    --region $Region | Out-Null

Write-Host "✓ GET method for /statistics created" -ForegroundColor Green

# Integrate Query Lambda with /analysis endpoint
Write-Host "[9/12] Integrating Query Lambda with /analysis..." -ForegroundColor Yellow

$queryIntegrationUri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/$QueryLambdaArn/invocations"

aws apigateway put-integration `
    --rest-api-id $ApiId `
    --resource-id $AnalysisResourceId `
    --http-method GET `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $queryIntegrationUri `
    --region $Region | Out-Null

Write-Host "✓ Query Lambda integration configured" -ForegroundColor Green

# Integrate Statistics Lambda with /statistics endpoint
Write-Host "[10/12] Integrating Statistics Lambda with /statistics..." -ForegroundColor Yellow

$statsIntegrationUri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/$StatsLambdaArn/invocations"

aws apigateway put-integration `
    --rest-api-id $ApiId `
    --resource-id $StatisticsResourceId `
    --http-method GET `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $statsIntegrationUri `
    --region $Region | Out-Null

Write-Host "✓ Statistics Lambda integration configured" -ForegroundColor Green

# Grant API Gateway permission to invoke Lambda functions
Write-Host "[11/12] Granting API Gateway permissions..." -ForegroundColor Yellow

$analysisSourceArn = "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/GET/api/v1/tremor/analysis"
$statisticsSourceArn = "arn:aws:execute-api:${Region}:${AccountId}:${ApiId}/*/GET/api/v1/tremor/statistics"

try {
    aws lambda add-permission `
        --function-name $QueryLambdaName `
        --statement-id "apigateway-analysis-$ApiId" `
        --action lambda:InvokeFunction `
        --principal apigateway.amazonaws.com `
        --source-arn $analysisSourceArn `
        --region $Region 2>&1 | Out-Null
    
    Write-Host "✓ Permission granted for Query Lambda" -ForegroundColor Green
} catch {
    Write-Host "⚠ Permission may already exist" -ForegroundColor Yellow
}

try {
    aws lambda add-permission `
        --function-name $StatsLambdaName `
        --statement-id "apigateway-statistics-$ApiId" `
        --action lambda:InvokeFunction `
        --principal apigateway.amazonaws.com `
        --source-arn $statisticsSourceArn `
        --region $Region 2>&1 | Out-Null
    
    Write-Host "✓ Permission granted for Statistics Lambda" -ForegroundColor Green
} catch {
    Write-Host "⚠ Permission may already exist for Statistics Lambda" -ForegroundColor Yellow
}

# Deploy API
Write-Host "[12/12] Deploying API to stage: $StageName..." -ForegroundColor Yellow

# Deploy API
Write-Host "[12/12] Deploying API to stage: $StageName..." -ForegroundColor Yellow
aws apigateway create-deployment `
    --rest-api-id $ApiId `
    --stage-name $StageName `
    --stage-description "Production deployment" `
    --description "Deployment of tremor analysis and statistics API" `
    --region $Region | Out-Null

Write-Host "✓ API deployed" -ForegroundColor Green

# Construct API endpoint URL
$ApiEndpoint = "https://${ApiId}.execute-api.${Region}.amazonaws.com/${StageName}"

# Test the API endpoints
Write-Host ""
Write-Host "Testing API endpoints..." -ForegroundColor Yellow

# Test analysis endpoint
Write-Host "  Testing /analysis endpoint..." -ForegroundColor Gray
try {
    $testUrl = "${ApiEndpoint}/api/v1/tremor/analysis?patient_id=PAT-001&limit=1"
    $testResponse = Invoke-RestMethod -Uri $testUrl -Method Get -ErrorAction Stop
    
    if ($testResponse.success) {
        Write-Host "✓ Analysis API working! Found $($testResponse.count) records" -ForegroundColor Green
    } else {
        Write-Host "⚠ Analysis API returned success=false (probably no data yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Analysis API test failed (OK if DynamoDB is empty)" -ForegroundColor Yellow
}

# Test statistics endpoint
Write-Host "  Testing /statistics endpoint..." -ForegroundColor Gray
try {
    $statsUrl = "${ApiEndpoint}/api/v1/tremor/statistics?patient_id=PAT-001"
    $statsResponse = Invoke-RestMethod -Uri $statsUrl -Method Get -ErrorAction Stop
    
    if ($statsResponse.success) {
        Write-Host "✓ Statistics API working!" -ForegroundColor Green
    } else {
        Write-Host "⚠ Statistics API returned success=false (probably no data yet)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Statistics API test failed (OK if DynamoDB is empty)" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Gateway Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "API Details:" -ForegroundColor White
Write-Host "  API ID:     $ApiId" -ForegroundColor White
Write-Host "  Region:     $Region" -ForegroundColor White
Write-Host "  Stage:      $StageName" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoint:" -ForegroundColor Yellow
Write-Host "  $ApiEndpoint" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available Endpoints:" -ForegroundColor Yellow
Write-Host "  1. Tremor Analysis (Query patient data):" -ForegroundColor White
Write-Host "     ${ApiEndpoint}/api/v1/tremor/analysis?patient_id=PAT-001" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Tremor Statistics (Aggregated metrics):" -ForegroundColor White
Write-Host "     ${ApiEndpoint}/api/v1/tremor/statistics?patient_id=PAT-001" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Update Flutter app_constants.dart with this endpoint:" -ForegroundColor White
Write-Host "     static const String _productionBaseUrl = '$ApiEndpoint';" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Generate test data:" -ForegroundColor White
Write-Host "     python generate_test_data.py --patients 3 --hours 48" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Test both endpoints:" -ForegroundColor White
Write-Host "     curl '$ApiEndpoint/api/v1/tremor/analysis?patient_id=PAT-001&limit=5'" -ForegroundColor Cyan
Write-Host "     curl '$ApiEndpoint/api/v1/tremor/statistics?patient_id=PAT-001'" -ForegroundColor Cyan
Write-Host ""

# Save API endpoint to file
$ApiEndpoint | Out-File -FilePath "api_endpoint.txt" -Encoding utf8
Write-Host "API endpoint saved to: api_endpoint.txt" -ForegroundColor Gray
Write-Host ""

exit 0
