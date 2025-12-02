param(
    [string]$FunctionName = "medusa-process-sensor-data",
    [string]$RuleName = "MedusaProcessingSchedule",
    [string]$Region = "us-east-1",
    [string]$ScheduleExpression = "rate(1 minute)"
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up EventBridge schedule for $FunctionName..." -ForegroundColor Cyan

# Get Account ID
$accountId = aws sts get-caller-identity --query Account --output text
$functionArn = "arn:aws:lambda:${Region}:${accountId}:function:${FunctionName}"

# 1. Create Rule
Write-Host "Creating EventBridge rule: $RuleName..."
aws events put-rule `
    --name $RuleName `
    --schedule-expression $ScheduleExpression `
    --state ENABLED `
    --region $Region

# 2. Add Permission for EventBridge to invoke Lambda
Write-Host "Adding Lambda permission..."
try {
    aws lambda add-permission `
        --function-name $FunctionName `
        --statement-id "${RuleName}-permission" `
        --action 'lambda:InvokeFunction' `
        --principal events.amazonaws.com `
        --source-arn "arn:aws:events:${Region}:${accountId}:rule/${RuleName}" `
        --region $Region
}
catch {
    Write-Host "  Permission might already exist (ignoring error)" -ForegroundColor Gray
}

# 3. Add Target
Write-Host "Adding target to rule..."
# Construct a JSON payload for the target input if needed, or use default
# The Lambda expects device_id, but for batch processing of ALL devices, 
# we might need to adjust the Lambda or pass a specific payload.
# Based on process_sensor_data.py, if device_id is missing, it returns 400.
# However, for a generic scheduled trigger, it should probably scan all active devices.
# Let's check if the Lambda supports a "scan all" mode or if we need to trigger for specific devices.
# The current Lambda implementation (lines 134-140) REQUIRES device_id.
# This is a limitation. The schedule needs to know WHICH device to process.
# OR the Lambda should be updated to find active devices.

# For now, let's assume we are processing for the known device 'DEV-002' (from user context/previous files).
# Ideally, we should have a "Orchestrator" lambda that finds active devices and invokes the processor for each.
# But to unblock the user, we will trigger for 'DEV-002'.

$payload = @{
    device_id     = "medusa-pi-01"
    window_size   = 100
    sampling_rate = 100
} | ConvertTo-Json -Compress

# Escape quotes for the JSON string inside the targets JSON
$escapedPayload = $payload.Replace('"', '\"')

$targetsJson = @"
[
    {
        "Id": "1",
        "Arn": "$functionArn",
        "Input": "$escapedPayload"
    }
]
"@

$targetsJson | Out-File -Encoding ascii -FilePath targets.json

aws events put-targets `
    --rule $RuleName `
    --targets file://targets.json `
    --region $Region

Remove-Item targets.json

Write-Host "✓ Schedule setup complete!" -ForegroundColor Green
Write-Host "  Rule: $RuleName"
Write-Host "  Target: $FunctionName"
Write-Host "  Payload: $payload"
