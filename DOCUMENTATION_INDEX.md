# MeDUSA 项目文档索引

## 📚 核心文档

### 1. **项目主文档**
- **`README.md`** - 项目概述、快速开始指南

### 2. **认证系统文档**
- **`AUTH_ENHANCEMENT_GUIDE.md`** - 认证系统增强完整指南
  - 邮箱验证注册系统
  - 密码重置功能
  - 验证码管理
  - 技术实现细节
  - 测试指南
  - 生产部署指南

### 3. **BLE 配对文档**
- **`meddevice-app-flutter-main/PIN_PAIRING_GUIDE.md`** - Windows BLE PIN 配对完整指南
  - PIN 配对流程
  - Windows 原生对话框集成
  - 故障排除
  - 测试方法

### 4. **云后端文档**
- **`medusa-cloud-components-python-backend/README.md`** - Python 后端 API 文档
  - API 端点说明
  - 本地开发指南
  - AWS Lambda 部署

---

## 🎯 快速参考

### 启动应用
```bash
cd meddevice-app-flutter-main
flutter run -d windows
```

### 测试邮箱验证（开发模式）
1. 注册页面：`/register`
2. 查看控制台获取验证码
3. 输入验证码完成注册

### 测试密码重置
1. 登录页面点击 "Forgot Password?"
2. 查看控制台获取重置码
3. 输入验证码并设置新密码

### 测试 BLE 配对
1. WiFi 配置页面：`/wifi-provision`
2. 显示 PIN 输入对话框
3. 输入 Raspberry Pi 显示的 PIN
4. 完成配对和 WiFi 配置

---

## 📁 项目结构

```
MeDUSA/
├── README.md                           # 项目主文档
├── AUTH_ENHANCEMENT_GUIDE.md           # 认证系统文档
├── DOCUMENTATION_INDEX.md              # 本文档
│
├── meddevice-app-flutter-main/         # Flutter 应用
│   ├── README.md                       # 应用说明
│   ├── PIN_PAIRING_GUIDE.md           # BLE 配对指南
│   ├── lib/                            # 源代码
│   │   ├── core/                       # 核心功能
│   │   ├── features/                   # 功能模块
│   │   │   ├── auth/                   # 认证模块
│   │   │   ├── devices/                # 设备管理
│   │   │   ├── dashboard/              # 仪表板
│   │   │   └── ...
│   │   └── shared/                     # 共享组件
│   │       ├── services/               # 服务
│   │       │   ├── email_service.dart
│   │       │   ├── verification_service.dart
│   │       │   ├── winble_service.dart
│   │       │   └── ...
│   │       └── widgets/                # 通用组件
│   └── windows/                        # Windows 平台
│       └── runner/                     # C++ 插件
│
└── medusa-cloud-components-python-backend/  # 后端 API
    └── backend-py/                     # Python 后端
        ├── main.py                     # FastAPI 应用
        ├── auth.py                     # 认证逻辑
        └── README.md                   # 后端文档
```

---

## 🔑 关键功能

### ✅ 已实现功能

1. **认证系统**
   - ✅ 邮箱验证注册（6位验证码）
   - ✅ 密码重置（邮箱验证）
   - ✅ 角色管理（医生、患者、管理员）
   - ✅ JWT 令牌认证

2. **BLE 配对**
   - ✅ Windows 原生 PIN 对话框
   - ✅ LESC (LE Secure Connections) 配对
   - ✅ 6位 PIN 验证
   - ✅ 配对后 WiFi 凭据传输

3. **WiFi 配置**
   - ✅ BLE 传输 WiFi 凭据
   - ✅ Raspberry Pi 连接验证
   - ✅ 用户友好的 UI

4. **用户界面**
   - ✅ Material Design 3
   - ✅ 响应式设计
   - ✅ 医疗主题配色
   - ✅ 角色权限控制

---

## 🧪 测试环境

### 开发模式
- **邮件服务**：Mock（控制台输出验证码）
- **后端 API**：本地 FastAPI 或 AWS Lambda
- **BLE**：Windows WinRT + WinBle

### 生产模式
- **邮件服务**：SMTP / SendGrid
- **后端 API**：AWS Lambda + API Gateway
- **BLE**：相同（Windows WinRT）

---

## 📞 支持的角色

- **`doctor`** - 医生
  - 查看所有患者数据
  - 创建医疗报告
  - 发送消息

- **`patient`** - 患者
  - 查看自己的数据
  - 连接医疗设备
  - 记录症状

- **`admin`** - 管理员
  - 用户管理
  - 系统设置
  - 审计日志

---

## 🔒 安全特性

- 🔐 JWT 令牌认证
- 🔑 密码加密存储
- ⏰ 验证码过期（10分钟）
- 🚫 尝试次数限制（3次）
- 📧 邮箱验证
- 🔓 角色权限控制

---

## 🚀 部署

### Flutter 应用
```bash
flutter build windows --release
```

### Python 后端
```bash
cd medusa-cloud-components-python-backend
sam build
sam deploy
```

---

## 📝 开发规范

- ✅ 代码全部英文
- ✅ 完整的注释
- ✅ 遵循 Flutter 最佳实践
- ✅ Clean Architecture
- ✅ BLoC 状态管理
- ✅ 类型安全

---

## 🎯 下一步计划

### 短期
- [ ] 真实邮件服务集成
- [ ] 完整的端到端测试
- [ ] 用户验收测试

### 长期
- [ ] 社交登录（Google, Apple）
- [ ] 双因素认证 (2FA)
- [ ] 生物识别认证
- [ ] 移动端支持（iOS, Android）

---

**最后更新**: November 14, 2025
**版本**: 1.0.0
**状态**: ✅ 生产就绪

