# 🚀 AWS SES 快速配置 - 5 分钟启用真实邮件

**目标**: 让用户在注册/密码重置时收到真实的验证码邮件

---

## ⚡ 最快配置方法（推荐）

### 🎯 方案 A: 使用你自己的邮箱测试（最简单）

**适合**: 快速测试，立即看到效果

#### Step 1: 验证你的邮箱（2 分钟）

1. **打开 AWS SES Console**:
   ```
   https://console.aws.amazon.com/ses/home?region=us-east-1#/verified-identities
   ```

2. **点击 "Create identity"**

3. **选择 "Email address"**

4. **输入你的邮箱**（例如：`andysun12@outlook.com`）

5. **点击 "Create identity"**

6. **检查邮箱** → 收到 AWS 的验证邮件 → **点击验证链接**

7. **确认状态变为 "Verified"** ✅

#### Step 2: 运行配置脚本（2 分钟）

```powershell
cd MeDUSA\medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\configure-ses.ps1
```

**按提示输入你的邮箱**（刚才验证的那个）

#### Step 3: 测试！（1 分钟）

1. 运行 Flutter 应用:
   ```powershell
   cd ..\..\meddevice-app-flutter-main
   flutter run -d windows
   ```

2. 点击 **"Register"** 或 **"Forgot Password?"**

3. 输入邮箱: `andysun12@outlook.com` ⚠️ **必须是已验证的邮箱**

4. 点击 **"Send Verification Code"**

5. **检查邮箱** 📬 - 你应该收到一封漂亮的 HTML 邮件！

---

## 📧 沙盒模式说明

### 什么是沙盒模式？

AWS SES 默认在沙盒模式，有以下限制：

| 限制 | 沙盒模式 | 生产模式 |
|------|---------|---------|
| **收件人** | ⚠️ 只能发送到已验证的邮箱 | ✅ 任意邮箱 |
| **每天限额** | 200 封 | 50,000+ 封 |
| **每秒限额** | 1 封 | 14+ 封 |

### 在沙盒模式测试

**最简单的方法**：使用同一个邮箱作为发件人和收件人

1. ✅ 验证你的邮箱：`andysun12@outlook.com`
2. ✅ 配置为发件人：`andysun12@outlook.com`
3. ✅ 使用同一邮箱注册/重置密码
4. ✅ 检查邮箱 - 收到验证码！

**这样你只需要验证一个邮箱！**

---

## 🆙 移出沙盒模式（可选）

### 为什么要移出？

- ✅ 可以发送到**任意邮箱**
- ✅ 不需要预先验证收件人
- ✅ 更高的发送限额
- ✅ 生产环境就绪

### 如何申请？

1. **访问**:
   ```
   https://console.aws.amazon.com/ses/home?region=us-east-1#/account
   ```

2. **点击 "Request production access"**

3. **填写表格**:
   - **Mail type**: Transactional
   - **Website URL**: 你的项目网站（或 GitHub 链接）
   - **Use case description**:
     ```
     MeDUSA is a medical device monitoring system that sends 
     email verification codes during user registration and 
     password reset. We expect to send approximately 100-500 
     verification emails per day to healthcare professionals.
     ```
   - **Compliance**: We will monitor bounce and complaint rates
   - **Bounce handling**: We will remove invalid addresses

4. **提交** → 通常 **24 小时内**批准

5. **批准后** → 可以发送到任意邮箱！

---

## 🧪 测试邮件示例

### 你会收到什么？

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
From: MeDUSA Health System <your-email>
Subject: Email Verification Code - MeDUSA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    MeDUSA Health System
    Email Verification

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Verify Your Email Address

Thank you for registering with MeDUSA Health System.
To complete your registration, please use the 
following verification code:

┌─────────────────────┐
│    1 2 3 4 5 6      │
└─────────────────────┘

This code will expire in 10 minutes.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
© 2025 MeDUSA Health System
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔍 故障排查

### ❌ 问题 1: 邮件未收到

**检查清单**:
- [ ] 发件人邮箱已验证（AWS Console 显示 "Verified"）
- [ ] 在沙盒模式，收件人邮箱也已验证
- [ ] 检查垃圾邮件文件夹
- [ ] 等待 1-2 分钟（可能有延迟）
- [ ] 查看 CloudWatch 日志:
  ```bash
  aws logs tail /aws/lambda/medusa-api-v3 --follow
  ```

### ❌ 问题 2: "MessageRejected" 错误

**原因**: 收件人邮箱未验证（沙盒模式）

**解决方法**:
1. 在 AWS SES Console 验证收件人邮箱
2. 或使用已验证的邮箱测试
3. 或申请移出沙盒模式

### ❌ 问题 3: "Email address is not verified"

**原因**: 发件人邮箱未验证

**解决方法**:
1. 访问 AWS SES Console
2. 检查邮箱验证状态
3. 重新发送验证邮件（如需要）

### ❌ 问题 4: 邮件进入垃圾箱

**临时解决方法**:
- 将发件人添加到通讯录
- 标记为"非垃圾邮件"

**长期解决方法**（生产环境）:
- 使用域名邮箱（而不是个人邮箱）
- 配置 SPF、DKIM、DMARC 记录
- 移出沙盒模式

---

## 💰 费用

**AWS SES 定价**（非常便宜）:

| 邮件数量 | 费用 |
|---------|------|
| 前 62,000 封/月 | $0.10 per 1,000 |
| 100 封邮件 | **$0.01** |
| 1,000 封邮件 | **$0.10** |
| 10,000 封邮件 | **$1.00** |

**示例成本**:
- 每天 50 个用户注册 = 每月 1,500 封邮件 = **$0.15/月**
- 每天 200 个用户注册 = 每月 6,000 封邮件 = **$0.60/月**

**几乎免费！** 💰

---

## 📝 配置文件说明

### template.yaml 更新

已自动添加以下配置：

```yaml
Environment:
  Variables:
    USE_SES: 'true'  # 启用 SES
    SENDER_EMAIL: 'your-email@example.com'  # 你的邮箱
    AWS_REGION: 'us-east-1'

Policies:
  - Statement:
    - Effect: Allow
      Action:
        - ses:SendEmail
        - ses:SendRawEmail
      Resource: '*'
```

### 如何手动修改发件人邮箱？

编辑 `template.yaml`:
```yaml
SENDER_EMAIL: 'new-email@example.com'
```

然后重新部署:
```powershell
sam build
sam deploy --no-confirm-changeset
```

---

## ✅ 完整检查清单

### AWS Console
- [ ] 已登录 AWS Console
- [ ] 区域设置为 us-east-1
- [ ] 发件人邮箱已验证 ✅
- [ ] （沙盒模式）收件人邮箱已验证
- [ ] （可选）已申请移出沙盒

### 代码配置
- [ ] template.yaml 已更新
- [ ] SENDER_EMAIL 设置正确
- [ ] USE_SES 设置为 'true'
- [ ] 已运行 sam build
- [ ] 已运行 sam deploy

### 测试
- [ ] Flutter 应用运行正常
- [ ] 点击发送验证码
- [ ] 收到邮件 📬
- [ ] 验证码正确
- [ ] 邮件格式美观

---

## 🎯 快速命令

### 一键配置（推荐）
```powershell
cd MeDUSA\medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\configure-ses.ps1
```

### 手动部署
```powershell
# 更新 template.yaml 中的 SENDER_EMAIL
sam build
sam deploy --no-confirm-changeset
```

### 查看日志
```powershell
aws logs tail /aws/lambda/medusa-api-v3 --follow --format short
```

### 测试 API
```powershell
curl -X POST "https://YOUR-API-URL/Prod/api/v1/auth/send-verification-code" `
  -H "Content-Type: application/json" `
  -d '{"email":"your-email@example.com","code":"123456","type":"registration"}'
```

---

## 🎉 成功标志

当你看到以下内容时，说明配置成功：

1. ✅ AWS Console 显示邮箱 "Verified"
2. ✅ 部署成功（CloudFormation UPDATE_COMPLETE）
3. ✅ Flutter 应用发送验证码成功
4. ✅ **邮箱收到漂亮的 HTML 邮件** 📬
5. ✅ 验证码可以正常使用

---

## 📞 需要帮助？

### 查看文档
- `AWS_SES配置指南.md` - 完整详细指南
- AWS SES Console: https://console.aws.amazon.com/ses/
- AWS SES Documentation: https://docs.aws.amazon.com/ses/

### 查看日志
```bash
# 实时日志
aws logs tail /aws/lambda/medusa-api-v3 --follow

# 最近 10 分钟
aws logs tail /aws/lambda/medusa-api-v3 --since 10m
```

### 检查 SES 状态
1. 访问 SES Console
2. 检查 "Verified identities"
3. 查看 "Sending statistics"
4. 检查 "Suppression list"（退信列表）

---

**🎊 现在开始吧！只需 5 分钟即可收到真实的验证码邮件！**

```powershell
cd MeDUSA\medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\configure-ses.ps1
```

