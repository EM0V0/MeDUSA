# Test script to run Flutter app with a predefined PIN
# Usage: .\test_with_pin.ps1 [PIN]
# Example: .\test_with_pin.ps1 123456

param(
    [string]$Pin = "123456"
)

Write-Host "Setting MEDUSA_TEST_PIN environment variable to: $Pin" -ForegroundColor Green
$env:MEDUSA_TEST_PIN = $Pin

Write-Host "Starting Flutter app..." -ForegroundColor Cyan
Write-Host "The app will automatically use PIN: $Pin for BLE pairing" -ForegroundColor Yellow
Write-Host ""

flutter run -d windows
