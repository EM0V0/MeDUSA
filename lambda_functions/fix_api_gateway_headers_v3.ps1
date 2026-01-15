# Fix API Gateway Security Headers (File-based version)
$ApiId = "zcrqexrdw1"
$Region = "us-east-1"

Write-Host "Configuring Gateway Responses for API: $ApiId..."

# Create JSON content
$JsonContent = @{
    "gatewayresponse.header.Strict-Transport-Security" = "'max-age=31536000; includeSubDomains'"
    "gatewayresponse.header.X-Content-Type-Options" = "'nosniff'"
    "gatewayresponse.header.X-Frame-Options" = "'DENY'"
    "gatewayresponse.header.Content-Security-Policy" = "'default-src ''self'''"
} | ConvertTo-Json

# Save to temp file
$JsonFile = "gateway-params.json"
$JsonContent | Out-File -Encoding ascii -FilePath $JsonFile

Write-Host "Using parameters from $JsonFile"
Get-Content $JsonFile

$ResponseTypes = @("DEFAULT_4XX", "DEFAULT_5XX", "ACCESS_DENIED", "UNAUTHORIZED", "THROTTLED")

foreach ($Type in $ResponseTypes) {
    Write-Host "Updating $Type..."
    
    # Use file:// prefix to read from file
    aws apigateway put-gateway-response `
        --rest-api-id $ApiId `
        --response-type $Type `
        --response-parameters "file://$JsonFile" `
        --region $Region
}

# Cleanup
Remove-Item $JsonFile

Write-Host "Deploying changes..."
aws apigateway create-deployment `
    --rest-api-id $ApiId `
    --stage-name "Prod" `
    --region $Region

Write-Host "✅ Done!"
