# MeDUSA - Medical Data Unified System & Analytics

专业的医疗数据融合与分析系统

---

## 🚀 快速启动

### 前端应用（Flutter）

```powershell
cd meddevice-app-flutter-main
flutter pub get
flutter run
```

**前端已自动配置连接到云端 API** ✅

### 后端 API

**生产环境（AWS Lambda）**
- API 地址: `https://zcrqexrdw1.execute-api.us-east-1.amazonaws.com/Prod/api/v1`
- 状态: ✅ 已部署运行
- 测试: 100% 通过 (8/8)

**本地测试（可选）**
```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend\backend-py
.\start_local.ps1
```

**更新云端部署**
```powershell
cd medusa-cloud-components-python-backend\medusa-cloud-components-python-backend
.\deploy.ps1
```

---

## 📋 系统架构

### 前端（Flutter）
- **框架**: Flutter 3.x
- **平台**: Web, Windows, Android, iOS
- **UI**: Material Design 3
- **状态管理**: Riverpod
- **网络**: Dio + TLS 1.3 安全通信

### 后端（Python FastAPI）
- **框架**: FastAPI + Uvicorn
- **部署**: AWS Lambda + API Gateway
- **数据库**: DynamoDB (Users, Poses, RefreshTokens)
- **存储**: S3
- **认证**: JWT (bcrypt + PyJWT)
- **API**: RESTful, OpenAPI 3.0, camelCase

### 云服务（AWS）
- **Lambda**: Python 3.10 运行时
- **API Gateway**: REST API
- **DynamoDB**: NoSQL 数据库（按需计费）
- **S3**: 文件存储
- **Secrets Manager**: JWT 密钥管理

---

## 📝 API 端点

所有端点使用 `/api/v1` 前缀：

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/admin/health` | 健康检查 |
| POST | `/auth/register` | 用户注册 |
| POST | `/auth/login` | 用户登录 |
| POST | `/auth/refresh` | 刷新令牌 |
| POST | `/auth/logout` | 用户登出 |
| GET | `/me` | 获取当前用户 |
| POST | `/poses` | 创建姿态数据 |
| GET | `/poses?patientId={id}` | 列出姿态数据 |

---

## 🔐 安全特性

### 前端安全
- ✅ TLS 1.3 强制加密
- ✅ 证书固定（Certificate Pinning）
- ✅ 安全存储（Flutter Secure Storage）
- ✅ HTTPS Only 策略

### 后端安全
- ✅ JWT 令牌认证
- ✅ bcrypt 密码哈希
- ✅ CORS 配置
- ✅ 中间件认证
- ✅ AWS Secrets Manager

---

## 📊 部署状态

### 生产环境（AWS Lambda）
- **状态**: ✅ 运行中
- **区域**: us-east-1
- **测试**: 100% 通过 (8/8)
- **API 网关**: `zcrqexrdw1.execute-api.us-east-1.amazonaws.com`

### 成本预估
- **月费用**: ~$0.40 - $12
- **大部分在 AWS 免费套餐内**

详见: `CLOUD_DEPLOYMENT_SUCCESS.md`

---

## 📚 文档

- **架构分析**: `ARCHITECTURE_ANALYSIS.md`
- **部署报告**: `CLOUD_DEPLOYMENT_SUCCESS.md`
- **快速启动**: `START.md`

---

## 🛠️ 开发环境

### 必需软件
- Flutter SDK 3.x
- Python 3.10+
- AWS CLI (部署用)
- AWS SAM CLI (部署用)
- PowerShell 5.0+

### 前端配置
```yaml
# pubspec.yaml (主要依赖)
dependencies:
  flutter_riverpod: ^2.4.0
  dio: ^5.4.0
  go_router: ^13.0.0
  fl_chart: ^0.66.0
```

### 后端配置
```txt
# requirements.txt
fastapi==0.115.2
mangum==0.17.0
boto3==1.35.36
bcrypt==4.2.0
PyJWT==2.9.0
uvicorn==0.32.0
```

---

## 🎯 项目状态

- ✅ 后端 API 开发完成
- ✅ API v3 规范完全遵循
- ✅ AWS Lambda 部署完成
- ✅ 100% 测试通过
- ✅ 前端 Flutter 应用开发完成
- ✅ 前后端集成配置完成
- ⏳ 蓝牙设备集成开发中

---

## 📞 支持

有问题请查看：
1. `START.md` - 快速启动指南
2. `ARCHITECTURE_ANALYSIS.md` - 系统架构详解
3. `CLOUD_DEPLOYMENT_SUCCESS.md` - 部署状态和详情

---

**MeDUSA © 2025 - 专业医疗数据系统**
