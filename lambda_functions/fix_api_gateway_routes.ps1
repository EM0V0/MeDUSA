# Fix API Gateway Routes
# Adds a catch-all proxy to route everything else to medusa-api-v3

$ErrorActionPreference = "Stop"
$Region = "us-east-1"
$ApiName = "MeDUSA-Tremor-API"
$V3LambdaName = "medusa-api-v3"
$StageName = "Prod"

Write-Host "Fixing API Gateway Routes..." -ForegroundColor Cyan

# 1. Get API ID
$apis = aws apigateway get-rest-apis --region $Region --output json | ConvertFrom-Json
$api = $apis.items | Where-Object { $_.name -eq $ApiName }

if (-not $api) {
    Write-Host "API not found!" -ForegroundColor Red
    exit 1
}

$ApiId = $api.id
Write-Host "Found API: $ApiId" -ForegroundColor Green

# 2. Get Root Resource ID
$resources = aws apigateway get-resources --rest-api-id $ApiId --region $Region --output json | ConvertFrom-Json
$RootId = $resources.items | Where-Object { $_.path -eq "/" } | Select-Object -ExpandProperty id
Write-Host "Root Resource ID: $RootId" -ForegroundColor Green

# 3. Get V3 Lambda ARN
try {
    $lambda = aws lambda get-function --function-name $V3LambdaName --region $Region --output json | ConvertFrom-Json
    $LambdaArn = $lambda.Configuration.FunctionArn
    Write-Host "V3 Lambda ARN: $LambdaArn" -ForegroundColor Green
} catch {
    Write-Host "V3 Lambda not found!" -ForegroundColor Red
    exit 1
}

# 4. Create /{proxy+} Resource
Write-Host "Creating /{proxy+} resource..." -ForegroundColor Yellow
try {
    $proxyResource = aws apigateway create-resource `
        --rest-api-id $ApiId `
        --parent-id $RootId `
        --path-part "{proxy+}" `
        --region $Region `
        --output json | ConvertFrom-Json
    $ProxyId = $proxyResource.id
    Write-Host "Created Proxy Resource: $ProxyId" -ForegroundColor Green
} catch {
    # Check if it already exists
    $existingProxy = $resources.items | Where-Object { $_.path -eq "/{proxy+}" }
    if ($existingProxy) {
        $ProxyId = $existingProxy.id
        Write-Host "Proxy Resource already exists: $ProxyId" -ForegroundColor Yellow
    } else {
        Write-Host "Failed to create proxy resource: $_" -ForegroundColor Red
        exit 1
    }
}

# 5. Create ANY Method
Write-Host "Creating ANY method..." -ForegroundColor Yellow
try {
    aws apigateway put-method `
        --rest-api-id $ApiId `
        --resource-id $ProxyId `
        --http-method ANY `
        --authorization-type NONE `
        --region $Region | Out-Null
    Write-Host "Created ANY method" -ForegroundColor Green
} catch {
    Write-Host "Method might already exist" -ForegroundColor Yellow
}

# 6. Integrate with Lambda
Write-Host "Integrating with Lambda..." -ForegroundColor Yellow
$integrationUri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/${LambdaArn}/invocations"

aws apigateway put-integration `
    --rest-api-id $ApiId `
    --resource-id $ProxyId `
    --http-method ANY `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $integrationUri `
    --region $Region | Out-Null
Write-Host "Integration configured" -ForegroundColor Green

# 7. Add Permission
Write-Host "Adding Lambda permission..." -ForegroundColor Yellow
$sourceArn = "arn:aws:execute-api:${Region}:*:${ApiId}/*/*/{proxy+}"

try {
    aws lambda add-permission `
        --function-name $V3LambdaName `
        --statement-id "apigateway-proxy-$ApiId" `
        --action lambda:InvokeFunction `
        --principal apigateway.amazonaws.com `
        --source-arn $sourceArn `
        --region $Region | Out-Null
    Write-Host "Permission added" -ForegroundColor Green
} catch {
    Write-Host "Permission might already exist" -ForegroundColor Yellow
}

# 8. Deploy API
Write-Host "Deploying API..." -ForegroundColor Yellow
aws apigateway create-deployment `
    --rest-api-id $ApiId `
    --stage-name $StageName `
    --region $Region | Out-Null
Write-Host "API Deployed!" -ForegroundColor Green

Write-Host "Done. Please wait a minute for changes to propagate." -ForegroundColor Cyan
