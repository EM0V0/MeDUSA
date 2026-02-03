# MeDUSA Email Delivery Diagnostic Tool
# This script helps diagnose email delivery issues

$apiUrl = "https://ycg6z39iy7.execute-api.us-east-1.amazonaws.com/Prod"

Write-Host "=== MeDUSA Email Delivery Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check SES Statistics
Write-Host "1. Checking AWS SES Statistics..." -ForegroundColor Yellow
$stats = aws ses get-send-statistics --region us-east-1 --output json | ConvertFrom-Json
$latest = $stats.SendDataPoints | Sort-Object Timestamp -Descending | Select-Object -First 1
Write-Host "   Latest: $($latest.Timestamp)"
Write-Host "   Delivery Attempts: $($latest.DeliveryAttempts)"
Write-Host "   Bounces: $($latest.Bounces)"
Write-Host "   Complaints: $($latest.Complaints)"
Write-Host ""

# 2. Check Verified Emails
Write-Host "2. Checking Verified Email Addresses..." -ForegroundColor Yellow
$verified = aws ses list-identities --region us-east-1 --output json | ConvertFrom-Json
Write-Host "   Verified: $($verified.Identities -join ', ')"
Write-Host ""

# 3. Test Email Sending
Write-Host "3. Testing Email Sending..." -ForegroundColor Yellow
$testEmail = Read-Host "   Enter email to test (or press Enter to use andysun12@outlook.com)"
if ([string]::IsNullOrWhiteSpace($testEmail)) {
    $testEmail = "andysun12@outlook.com"
}

$requestBody = @{
    email = $testEmail
    type = "registration"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "$apiUrl/api/v1/auth/request-verification" -Method POST -Body $requestBody -ContentType "application/json"
    Write-Host "   [OK] Verification code request sent!" -ForegroundColor Green
    Write-Host "   Response: $($result | ConvertTo-Json -Compress)"
} catch {
    Write-Host "   [ERROR] Failed to send: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Checking Lambda Logs (last 30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
aws logs tail /aws/lambda/medusa-api-v3 --since 30s --region us-east-1 --format short 2>&1 | Select-String -Pattern "EmailService|Message ID" | Select-Object -Last 10

Write-Host ""
Write-Host "=== Diagnostic Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If emails are not arriving:" -ForegroundColor Yellow
Write-Host "1. Check Spam/Junk folder in Outlook"
Write-Host "2. Check Outlook web: https://outlook.live.com"
Write-Host "3. Search for 'MeDUSA' or 'zsun54@jh.edu'"
Write-Host "4. Check email rules/filters in Outlook"
Write-Host "5. Check 'Focused' vs 'Other' tabs in Outlook"
Write-Host "6. Emails might be delayed (SES sandbox rate limits)"
Write-Host ""
Write-Host "To check SES suppression list:" -ForegroundColor Yellow
Write-Host "https://console.aws.amazon.com/ses/home?region=us-east-1#/suppression-list"
Write-Host ""
