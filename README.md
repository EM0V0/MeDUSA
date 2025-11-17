# MeDUSA - Medical Data Unified System & Analytics

专业的医疗数据融合与分析系统

---

## 🎉 前端优化完成 ✅

**已删除无用功能**：
- ❌ 两步验证（2FA）
- ❌ SSO登录（Google, Apple, Microsoft）
- ❌ Demo Login和测试按钮
- ❌ 审计日志
- ❌ 系统设置管理
- ❌ 云端设备管理

**已简化页面**：
- 🔧 用户管理页面（1052行 → 453行，减少57%）
- 🔧 登录页面（519行 → 241行，减少53.6%）

**已修复功能**：
- ✅ 登录/注册连接真实后端API
- ✅ AuthBloc状态管理完善
- ✅ 自动跳转和错误处理

**完整保留功能**：
- ✅ 所有蓝牙相关功能
- ✅ 用户认证（登录、注册、登出）
- ✅ 患者数据管理
- ✅ 症状记录
- ✅ 报告功能

**前后端功能**：100% 对应 ✅

详见：`登录注册修复完成.md` | `测试指南.txt`

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
- **蓝牙**: flutter_blue_plus (完整保留)

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

## 🔐 RBAC 角色权限

| 角色 | 代码 | 权限 |
|------|------|------|
| **患者** | `patient` | 查看自己数据、连接蓝牙设备、记录症状 |
| **医生** | `doctor` | 查看所有患者数据、生成报告、管理患者 |
| **管理员** | `admin` | 所有权限 + 用户管理 |

**JWT Token 包含角色信息**：
```json
{
  "sub": "usr_xxx",
  "role": "patient",
  "exp": 1234567890
}
```

**RBAC 实现**：
- ✅ `lib/core/auth/role_permissions.dart` - 权限配置
- ✅ `lib/shared/widgets/permission_widget.dart` - 权限组件

---

## 🔵 蓝牙功能（完整保留）

### 页面
- ✅ 设备扫描页面 (`device_scan_page.dart`)
- ✅ 设备连接页面 (`device_connection_page.dart`)
- ✅ WiFi配置页面 (`wifi_provision_page.dart`)
- ✅ Windows BLE测试 (`winble_test_page.dart`)

### 服务
- ✅ 蓝牙适配器 (`bluetooth_adapter.dart`)
- ✅ 蓝牙服务 (`bluetooth_service.dart`)
- ✅ WiFi辅助服务 (`wifi_helper_bluetooth_service.dart`)

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

- **快速启动**: `启动说明.txt` / `START.md`
- **架构分析**: `ARCHITECTURE_ANALYSIS.md`
- **部署报告**: `CLOUD_DEPLOYMENT_SUCCESS.md`

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
  flutter_blue_plus: ^1.32.0
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
- ✅ 前端功能清理完成
- ✅ RBAC 权限框架部署
- ✅ 蓝牙功能完整保留

---

## 📝 变更日志

### 2025-11-14（最新）
- ✅ **修复CORS跨域问题**（API Gateway配置完善）
- ✅ **修复登录注册功能**（连接真实后端API）
- ✅ API Gateway CORS headers从2个增加到7个
- ✅ 添加预检请求缓存（MaxAge: 600秒）
- ✅ 后端重新部署，测试通过
- ✅ 删除SSO登录代码（Google, Apple, Microsoft）
- ✅ 删除Demo Login和测试按钮
- ✅ 简化登录页面（519行 → 241行，减少53.6%）
- ✅ 实现BlocListener自动导航
- ✅ 完善错误处理和加载状态
- ✅ 清理前端无用功能（删除6个文件）
- ✅ 简化用户管理页面（1052行 → 453行）
- ✅ 更新路由配置（移除已删除页面路由）
- ✅ 保持蓝牙功能完整
- ✅ 确保前后端功能100%对应
- ✅ 部署 RBAC 权限控制框架

---

**MeDUSA © 2025 - 专业医疗数据系统**
