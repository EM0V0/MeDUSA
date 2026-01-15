# Fix API Gateway Security Headers (JSON version)
$ApiId = "zcrqexrdw1"
$Region = "us-east-1"

Write-Host "Configuring Gateway Responses for API: $ApiId..."

# Use JSON format for parameters to avoid parsing issues
# Note: Values must be single-quoted inside the JSON string for API Gateway
$JsonParams = '{"gatewayresponse.header.Strict-Transport-Security":"''max-age=31536000; includeSubDomains''","gatewayresponse.header.X-Content-Type-Options":"''nosniff''","gatewayresponse.header.X-Frame-Options":"''DENY''","gatewayresponse.header.Content-Security-Policy":"''default-src ''''self''''''"}'

$ResponseTypes = @("DEFAULT_4XX", "DEFAULT_5XX", "ACCESS_DENIED", "UNAUTHORIZED", "THROTTLED")

foreach ($Type in $ResponseTypes) {
    Write-Host "Updating $Type..."
    
    aws apigateway put-gateway-response `
        --rest-api-id $ApiId `
        --response-type $Type `
        --response-parameters $JsonParams `
        --region $Region
}

Write-Host "Deploying changes..."
aws apigateway create-deployment `
    --rest-api-id $ApiId `
    --stage-name "Prod" `
    --region $Region

Write-Host "✅ Done!"
