param(
    [string]$DeviceId,
    [string]$Region = "us-east-1"
)

if (-not $DeviceId) {
    Write-Host "Please provide a Device ID." -ForegroundColor Red
    Write-Host "Usage: .\trigger_processing.ps1 -DeviceId <device_id>"
    exit 1
}

$payload = @{
    device_id = $DeviceId
    window_size = 10
    sampling_rate = 100
} | ConvertTo-Json -Compress

Write-Host "Triggering processing for device: $DeviceId" -ForegroundColor Cyan
aws lambda invoke `
    --function-name medusa-process-sensor-data `
    --payload $payload `
    --cli-binary-format raw-in-base64-out `
    --region $Region `
    response.json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Processing triggered successfully." -ForegroundColor Green
    Get-Content response.json | ConvertFrom-Json | ConvertTo-Json -Depth 5
    Remove-Item response.json
} else {
    Write-Host "✗ Failed to trigger processing." -ForegroundColor Red
}
