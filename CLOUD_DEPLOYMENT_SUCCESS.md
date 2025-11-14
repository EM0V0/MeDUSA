# ☁️ AWS Lambda 部署成功报告

**部署日期**: 2025-11-14  
**状态**: ✅ 成功  
**测试结果**: 🎉 **100% 通过** (8/8)

---

## 📋 部署信息

### API 端点
- **Base URL**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/`
- **API v1 URL**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1`
- **Swagger UI**: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/docs`
- **区域**: `us-east-1`

### AWS 资源
- **Lambda 函数**: `medusa-api-v3` (arn:aws:lambda:us-east-1:636750015010:function:medusa-api-v3)
- **API Gateway**: `medusa-api-v3`
- **CloudFormation Stack**: `medusa-api-v3-stack`

#### DynamoDB 表
- **Users Table**: `medusa-users-prod` (包含 `email-index` GSI)
- **Poses Table**: `medusa-poses-prod` 
- **Refresh Tokens Table**: `medusa-refresh-tokens-prod`

#### S3 存储桶
- **Data Bucket**: `medusa-data-prod-636750015010`

#### Secrets Manager
- **JWT Secret**: `medusa/jwt`

---

## ✅ 测试结果

### 完整测试套件 (100% 通过)

| # | 测试项 | 状态 | 说明 |
|---|--------|------|------|
| 1 | Health Check | ✅ | API 健康检查正常 |
| 2 | User Registration | ✅ | 用户注册成功，返回 API v3 格式 |
| 3 | User Login | ✅ | 用户登录成功，返回 JWT tokens |
| 4 | Get Current User | ✅ | 获取当前用户信息成功 |
| 5 | Create Pose | ✅ | 创建姿态数据成功 |
| 6 | List Poses | ✅ | 列出姿态数据成功 |
| 7 | Token Refresh | ✅ | 刷新 token 成功 |
| 8 | User Logout | ✅ | 用户登出成功 |

**成功率**: 100.0% (8/8)

---

## 🔧 部署过程中解决的问题

### 1. 权限配置
- **问题**: IAM 用户缺少必要的 AWS 服务权限
- **解决**: 添加了 AdministratorAccess 策略（开发环境）

### 2. JWT Secret JSON 格式
- **问题**: PowerShell `ConvertTo-Json` 创建的格式不正确
- **解决**: 使用手动转义的 JSON 字符串创建 secret

### 3. Python 编码问题
- **问题**: Lambda 运行时默认编码导致 `'gbk' codec can't encode` 错误
- **解决**: 在 Lambda 环境变量中设置 `PYTHONIOENCODING=utf-8`, `LC_ALL=C.UTF-8`, `LANG=C.UTF-8`

### 4. 环境变量名称不匹配
- **问题**: `db.py` 期待 `DDB_TABLE_USERS` 等环境变量，但 template.yaml 中使用了不同的名称
- **解决**: 更新 template.yaml 使用正确的环境变量名称

### 5. DynamoDB GSI 缺失
- **问题**: `get_user_by_email` 查询需要 `email-index` GSI
- **解决**: 在 UsersTable 中添加了 GlobalSecondaryIndex

### 6. Poses 表查询逻辑错误
- **问题**: 代码尝试使用不存在的 `patientId-index` GSI
- **解决**: 修改查询逻辑，直接使用 `patientId` 作为 HASH 键查询（无需 GSI）

---

## 📊 性能与成本

### Lambda 配置
- **Runtime**: Python 3.10
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **Architecture**: x86_64

### 预估成本（低流量场景）
- **Lambda**: ~$0.00 - $5.00/月 (包含在免费套餐内)
- **API Gateway**: ~$0.00 - $3.50/月 (前 100 万次请求免费)
- **DynamoDB**: ~$0.00 - $2.50/月 (按需计费，低流量)
- **S3**: ~$0.00 - $0.50/月 (数据存储很少)
- **Secrets Manager**: ~$0.40/月 (1 个 secret)

**总计**: **~$0.40 - $12/月** (大部分在免费套餐内)

---

## 🚀 使用指南

### API 调用示例

#### 健康检查
```bash
curl https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1/admin/health
```

#### 用户注册
```bash
curl -X POST https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Password123!","role":"patient"}'
```

#### 用户登录
```bash
curl -X POST https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Password123!"}'
```

---

## 🔄 更新部署

更新代码后重新部署：

```powershell
cd D:\25fall\Capstone\ble\MeDUSA\medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\deploy.ps1
```

或手动执行：

```powershell
sam build
sam deploy --stack-name medusa-api-v3-stack --region us-east-1 --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset
```

---

## 📝 监控与日志

### 查看 Lambda 日志
```powershell
sam logs -n MedusaAPIFunction --stack-name medusa-api-v3-stack --tail --region us-east-1
```

或使用 AWS CLI：
```powershell
aws logs tail /aws/lambda/medusa-api-v3 --follow --region us-east-1
```

### 查看 CloudWatch 指标
访问 AWS Console > CloudWatch > Log groups > `/aws/lambda/medusa-api-v3`

---

## 🎯 下一步

### 前端配置
更新 Flutter 应用的 API 端点：

```dart
const API_BASE_URL = 'https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1';
```

### 生产环境优化建议
1. **CORS**: 将 `allow_origins` 从 `["*"]` 改为具体的前端域名
2. **API Gateway**: 配置自定义域名和 SSL 证书
3. **监控**: 设置 CloudWatch Alarms 监控错误率和延迟
4. **备份**: 启用 DynamoDB 的 Point-in-Time Recovery (已启用)
5. **安全**: 实施 API Gateway 的 Usage Plans 和 API Keys（可选）

---

## ✨ 总结

MeDUSA 后端 API 已成功部署到 AWS Lambda！

- ✅ **所有测试通过** (100% 成功率)
- ✅ **API v3 完全兼容**
- ✅ **生产级 AWS 架构**
- ✅ **自动扩展和高可用**
- ✅ **低成本运行** (~$0.40-12/月)

**API 已准备好供前端调用！** 🚀

