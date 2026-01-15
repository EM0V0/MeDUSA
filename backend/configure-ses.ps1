# AWS SES 配置脚本
# 自动配置 SES 并部署更新

Write-Host "🔧 AWS SES 配置向导" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 获取用户邮箱
Write-Host "Step 1: 配置发件人邮箱" -ForegroundColor Yellow
Write-Host ""
Write-Host "请输入你要使用的发件人邮箱地址:" -ForegroundColor White
Write-Host "（这个邮箱将作为验证码邮件的发件人）" -ForegroundColor Gray
Write-Host ""
$senderEmail = Read-Host "发件人邮箱"

if (-not $senderEmail -or $senderEmail -notmatch "@") {
    Write-Host "❌ 无效的邮箱地址" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ 将使用邮箱: $senderEmail" -ForegroundColor Green
Write-Host ""

# Step 2: 更新 template.yaml
Write-Host "Step 2: 更新配置文件" -ForegroundColor Yellow
Write-Host ""

$templatePath = ".\template.yaml"
if (Test-Path $templatePath) {
    $content = Get-Content $templatePath -Raw
    $content = $content -replace "SENDER_EMAIL: '[^']*'", "SENDER_EMAIL: '$senderEmail'"
    Set-Content $templatePath $content -NoNewline
    Write-Host "✅ template.yaml 已更新" -ForegroundColor Green
} else {
    Write-Host "❌ 找不到 template.yaml" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: 验证邮箱（需要在 AWS Console 手动完成）
Write-Host "Step 3: 验证邮箱地址" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  重要: 你需要在 AWS Console 中验证邮箱" -ForegroundColor Yellow
Write-Host ""
Write-Host "请按照以下步骤操作:" -ForegroundColor White
Write-Host ""
Write-Host "1. 打开浏览器访问:" -ForegroundColor Cyan
Write-Host "   https://console.aws.amazon.com/ses/home?region=us-east-1#/verified-identities" -ForegroundColor White
Write-Host ""
Write-Host "2. 点击 'Create identity' 按钮" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 选择 'Email address'" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. 输入邮箱: $senderEmail" -ForegroundColor White
Write-Host ""
Write-Host "5. 点击 'Create identity'" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. 检查你的邮箱 ($senderEmail)" -ForegroundColor Cyan
Write-Host "   会收到一封来自 Amazon SES 的验证邮件" -ForegroundColor Gray
Write-Host ""
Write-Host "7. 点击邮件中的验证链接" -ForegroundColor Cyan
Write-Host ""
Write-Host "8. 返回这里继续" -ForegroundColor Cyan
Write-Host ""

Read-Host "完成上述步骤后，按 Enter 继续"

Write-Host ""

# Step 4: 确认是否在沙盒模式
Write-Host "Step 4: 沙盒模式检查" -ForegroundColor Yellow
Write-Host ""
Write-Host "AWS SES 默认在 '沙盒模式'，限制:" -ForegroundColor White
Write-Host "  - 只能发送到已验证的邮箱" -ForegroundColor Gray
Write-Host "  - 每天最多 200 封邮件" -ForegroundColor Gray
Write-Host ""
Write-Host "是否要在沙盒模式下测试? (推荐)" -ForegroundColor White
Write-Host "  Y - 是，在沙盒模式测试（需要验证收件人邮箱）" -ForegroundColor Gray
Write-Host "  N - 否，申请移出沙盒（可发送到任意邮箱，需审核）" -ForegroundColor Gray
Write-Host ""
$sandboxChoice = Read-Host "选择 (Y/N)"

if ($sandboxChoice -eq "N" -or $sandboxChoice -eq "n") {
    Write-Host ""
    Write-Host "📝 申请移出沙盒模式:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 访问:" -ForegroundColor White
    Write-Host "   https://console.aws.amazon.com/ses/home?region=us-east-1#/account" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. 点击 'Request production access'" -ForegroundColor White
    Write-Host ""
    Write-Host "3. 填写表格:" -ForegroundColor White
    Write-Host "   - Mail type: Transactional" -ForegroundColor Gray
    Write-Host "   - Use case: Medical system email verification" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. 提交申请（通常 24 小时内审核）" -ForegroundColor White
    Write-Host ""
    Write-Host "在申请批准前，你仍可以在沙盒模式测试" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "📧 沙盒模式测试" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "在沙盒模式下，收件人邮箱也需要验证" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "建议: 使用同一个邮箱($senderEmail)进行测试" -ForegroundColor White
    Write-Host "这样发件人和收件人都是已验证的邮箱" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Read-Host "按 Enter 继续部署"

# Step 5: 构建和部署
Write-Host ""
Write-Host "Step 5: 部署更新" -ForegroundColor Yellow
Write-Host ""

Write-Host "正在构建..." -ForegroundColor Cyan
sam build

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 构建失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "正在部署..." -ForegroundColor Cyan
sam deploy --no-confirm-changeset

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 部署失败" -ForegroundColor Red
    exit 1
}

# Step 6: 测试
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ 配置完成！" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📧 邮件配置信息:" -ForegroundColor Cyan
Write-Host "  发件人: $senderEmail" -ForegroundColor White
Write-Host "  SES 状态: 已启用" -ForegroundColor White
Write-Host "  区域: us-east-1" -ForegroundColor White
Write-Host ""

Write-Host "🧪 测试步骤:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 运行 Flutter 应用:" -ForegroundColor White
Write-Host "   cd ..\..\meddevice-app-flutter-main" -ForegroundColor Gray
Write-Host "   flutter run -d windows" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 点击 'Register' 或 'Forgot Password?'" -ForegroundColor White
Write-Host ""
Write-Host "3. 输入邮箱: $senderEmail" -ForegroundColor White
Write-Host "   (在沙盒模式，必须使用已验证的邮箱)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 点击 'Send Verification Code'" -ForegroundColor White
Write-Host ""
Write-Host "5. 检查你的邮箱 - 应该收到验证码！ 📬" -ForegroundColor White
Write-Host ""

Write-Host "💡 提示:" -ForegroundColor Yellow
Write-Host "  - 如果没收到邮件，检查垃圾邮件文件夹" -ForegroundColor Gray
Write-Host "  - 查看 CloudWatch 日志排查问题:" -ForegroundColor Gray
Write-Host "    aws logs tail /aws/lambda/medusa-api-v3 --follow" -ForegroundColor Gray
Write-Host ""

Write-Host "📚 更多信息:" -ForegroundColor Cyan
Write-Host "  - AWS_SES配置指南.md" -ForegroundColor White
Write-Host "  - https://console.aws.amazon.com/ses/" -ForegroundColor White
Write-Host ""

