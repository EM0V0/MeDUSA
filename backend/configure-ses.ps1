# AWS SES Configuration Script
# Automatically configure SES and deploy updates

Write-Host "🔧 AWS SES Configuration Wizard" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Configure Sender Email
Write-Host "Step 1: Configure Sender Email" -ForegroundColor Yellow
Write-Host ""
Write-Host "Please enter the sender email address you want to use:" -ForegroundColor White
Write-Host "(This email will be used as the sender for verification code emails)" -ForegroundColor Gray
Write-Host ""
$senderEmail = Read-Host "Sender Email"

if (-not $senderEmail -or $senderEmail -notmatch "@") {
    Write-Host "❌ Invalid email address" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Using email: $senderEmail" -ForegroundColor Green
Write-Host ""

# Step 2: Update Configuration File
Write-Host "Step 2: Update Configuration File" -ForegroundColor Yellow
Write-Host ""

$templatePath = ".\template.yaml"
if (Test-Path $templatePath) {
    $content = Get-Content $templatePath -Raw
    $content = $content -replace "SENDER_EMAIL: '[^']*'", "SENDER_EMAIL: '$senderEmail'"
    Set-Content $templatePath $content -NoNewline
    Write-Host "✅ template.yaml updated" -ForegroundColor Green
} else {
    Write-Host "❌ template.yaml not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Verify Email Address (Manual Step)
Write-Host "Step 3: Verify Email Address" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  IMPORTANT: You need to verify the email in AWS Console" -ForegroundColor Yellow
Write-Host ""
Write-Host "Please follow these steps:" -ForegroundColor White
Write-Host ""
Write-Host "1. Open browser and visit:" -ForegroundColor Cyan
Write-Host "   https://console.aws.amazon.com/ses/home?region=us-east-1#/verified-identities" -ForegroundColor White
Write-Host ""
Write-Host "2. Click 'Create identity' button" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Select 'Email address'" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Enter email: $senderEmail" -ForegroundColor White
Write-Host ""
Write-Host "5. Click 'Create identity'" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. Check your email ($senderEmail)" -ForegroundColor Cyan
Write-Host "   You will receive a verification email from Amazon SES" -ForegroundColor Gray
Write-Host ""
Write-Host "7. Click the verification link in the email" -ForegroundColor Cyan
Write-Host ""
Write-Host "8. Return here to continue" -ForegroundColor Cyan
Write-Host ""

Read-Host "After completing the above steps, press Enter to continue"

Write-Host ""

# Step 4: Sandbox Mode Check
Write-Host "Step 4: Sandbox Mode Check" -ForegroundColor Yellow
Write-Host ""
Write-Host "AWS SES is in 'Sandbox Mode' by default, with limits:" -ForegroundColor White
Write-Host "  - Can only send to verified emails" -ForegroundColor Gray
Write-Host "  - Max 200 emails per 24 hours" -ForegroundColor Gray
Write-Host ""
Write-Host "Do you want to test in Sandbox Mode? (Recommended)" -ForegroundColor White
Write-Host "  Y - Yes, test in Sandbox Mode (Recipient email must be verified)" -ForegroundColor Gray
Write-Host "  N - No, Request Production Access (Can send to any email, requires review)" -ForegroundColor Gray
Write-Host ""
$sandboxChoice = Read-Host "Choice (Y/N)"

if ($sandboxChoice -eq "N" -or $sandboxChoice -eq "n") {
    Write-Host ""
    Write-Host "📝 Request Production Access:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Visit:" -ForegroundColor White
    Write-Host "   https://console.aws.amazon.com/ses/home?region=us-east-1#/account" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Click 'Request production access'" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Fill out the form:" -ForegroundColor White
    Write-Host "   - Mail type: Transactional" -ForegroundColor Gray
    Write-Host "   - Use case: Medical system email verification" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Submit request (Usually reviewed within 24 hours)" -ForegroundColor White
    Write-Host ""
    Write-Host "You can still test in Sandbox Mode while waiting for approval" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "📧 Sandbox Mode Testing" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "In Sandbox Mode, recipient email must also be verified" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recommendation: Use the same email ($senderEmail) for testing" -ForegroundColor White
    Write-Host "This way both sender and recipient are verified" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to continue deployment"

# Step 5: Build and Deploy
Write-Host ""
Write-Host "Step 5: Deploy Updates" -ForegroundColor Yellow
Write-Host ""

Write-Host "Building..." -ForegroundColor Cyan
sam build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying..." -ForegroundColor Cyan
sam deploy --no-confirm-changeset

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    exit 1
}

# Step 6: Test
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ Configuration Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📧 Email Configuration Info:" -ForegroundColor Cyan
Write-Host "  Sender: $senderEmail" -ForegroundColor White
Write-Host "  SES Status: Enabled" -ForegroundColor White
Write-Host "  Region: us-east-1" -ForegroundColor White
Write-Host ""

Write-Host "🧪 Test Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Run Flutter App:" -ForegroundColor White
Write-Host "   cd ..\..\meddevice-app-flutter-main" -ForegroundColor Gray
Write-Host "   flutter run -d windows" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Click 'Register' or 'Forgot Password?'" -ForegroundColor White
Write-Host ""
Write-Host "3. Enter email: $senderEmail" -ForegroundColor White
Write-Host "   (In Sandbox Mode, must use verified email)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Click 'Send Verification Code'" -ForegroundColor White
Write-Host ""
Write-Host "5. Check your email - verification code should arrive! 📬" -ForegroundColor White
Write-Host ""

Write-Host "💡 Tips:" -ForegroundColor Yellow
Write-Host "  - Check spam folder if email not received" -ForegroundColor Gray
Write-Host "  - Check CloudWatch logs for troubleshooting:" -ForegroundColor Gray
Write-Host "    aws logs tail /aws/lambda/medusa-api-v3 --follow" -ForegroundColor Gray
Write-Host ""

Write-Host "📚 More Info:" -ForegroundColor Cyan
Write-Host "  - https://docs.aws.amazon.com/ses/latest/dg/Welcome.html" -ForegroundColor White
Write-Host "  - https://console.aws.amazon.com/ses/" -ForegroundColor White
Write-Host ""

