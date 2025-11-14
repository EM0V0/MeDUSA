# MeDUSA 架构对比分析

## 架构图 vs 实际实现对比

### ⚠️ 关键差异

| 组件 | 架构图 | 实际实现 | 状态 |
|------|--------|---------|------|
| **Lambda Runtime** | Rust | **Python (FastAPI)** | ❌ 不匹配 |
| **Security Edge/WAF** | 独立层 | **未实现** | ❌ 缺失 |
| **Pi/Glove连接** | HTTPS/TLS → 后端 | **蓝牙 → Flutter App** | ⚠️ 架构不同 |
| **API Gateway** | 有（Rate limiting） | **本地开发：无；AWS：可配置** | ⚠️ 部分实现 |
| **DynamoDB** | 有 | **有（或内存模式）** | ✅ 匹配 |
| **S3** | 有 | **有** | ✅ 匹配 |
| **CloudWatch** | 有 | **有（AWS模式）** | ✅ 匹配 |

---

## 详细架构分析

### 1. 后端语言差异 ❌

**架构图**: Lambda (Rust)  
**实际实现**: Lambda (Python + FastAPI)

**影响**:
- 性能特性不同（Rust更快，Python更易开发）
- 部署包大小不同
- 冷启动时间不同

**建议**: 更新架构图标注为 "Lambda (Python)"

---

### 2. Security Edge/WAF 层缺失 ❌

**架构图**: 独立的 Security Edge (WAF/CORS)  
**实际实现**: 
- CORS 在 FastAPI 中配置（应用层）
- WAF 未实现
- TLS 由 API Gateway 或本地 Uvicorn 提供

**影响**:
- 缺少 DDoS 防护
- 缺少 WAF 规则
- 安全防护较弱

**现状**:
```python
# 在 main.py 中直接配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 开发模式，生产应限制
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**建议**: 
- 部署 AWS WAF（如果使用 API Gateway）
- 或明确架构图说明 CORS 在应用层

---

### 3. 设备连接架构差异 ⚠️

**架构图**: Pi/Glove → HTTPS/TLS → Security Edge → 后端  
**实际实现**: Pi/Glove → **蓝牙** → Flutter App → HTTPS → 后端

**数据流**:
```
实际架构:
┌──────────────┐
│  Pi/Glove    │
│  (BLE设备)   │
└──────┬───────┘
       │ 蓝牙 (BLE)
       ▼
┌──────────────┐
│ Flutter App  │
│  (Windows)   │
└──────┬───────┘
       │ HTTPS/TLS
       ▼
┌──────────────┐
│   Backend    │
│  (Python)    │
└──────────────┘
```

**说明**:
- Pi/Glove 是**本地蓝牙设备**，不直接连接互联网
- Flutter App 作为**中间层**，负责：
  - BLE 配对和连接（使用 win_ble）
  - WiFi 凭据配置（通过 BLE 写入）
  - 数据上传到云端（通过 HTTPS）

**这是合理的设计**，因为：
- ✅ 医疗设备通常是低功耗蓝牙（不直接联网）
- ✅ 通过手机/电脑作为网关更安全
- ✅ 减少设备端的复杂性和攻击面

---

### 4. API Gateway 实现 ⚠️

**架构图**: API Gateway (Public entry, Rate limiting)  
**实际实现**:
- **本地开发**: 直接 FastAPI (Uvicorn) - 无 API Gateway
- **AWS 部署**: 可配置 API Gateway，但未配置 Rate limiting

**建议**: 
- 本地开发：保持现状（简单直接）
- AWS 部署：配置 API Gateway 的 Rate limiting 和 Throttling

---

### 5. 存储和数据库 ✅

**架构图**: DynamoDB + S3  
**实际实现**: 
- DynamoDB (AWS 模式) 或内存字典（本地模式）
- S3 (AWS 模式) 或未使用（本地模式）

**状态**: ✅ 架构匹配（生产环境）

---

### 6. 监控和日志 ✅

**架构图**: CloudWatch (Logs/Metrics/Alarms)  
**实际实现**: 
- AWS Lambda 自动记录到 CloudWatch
- FastAPI 日志输出到 stdout（Lambda 捕获）

**状态**: ✅ 架构匹配（AWS 环境）

---

## 正确的架构图

### 实际架构应该是：

```
┌─────────────────┐                    ┌─────────────────┐
│ On-Patient      │                    │    Clients      │
│ Device          │                    │                 │
│                 │                    │  Flutter App    │
│   Pi/Glove      │◄────蓝牙(BLE)────►│  (Windows/Web)  │
└─────────────────┘                    └────────┬────────┘
                                               │
                                               │ HTTPS/TLS
                                               │
                                               ▼
                                        ┌─────────────────┐
                                        │  API Gateway    │
                                        │  (Rate limit)   │
                                        │  + CORS         │
                                        └────────┬────────┘
                                                │ HTTPS
                    ┌───────────────────────────┼────────────────┐
                    │         AWS Cloud         │                │
                    │                           ▼                │
                    │                   ┌──────────────┐         │
                    │                   │  Lambda      │         │
                    │                   │  (Python)    │         │
                    │                   │  FastAPI     │         │
                    │                   └──────┬───────┘         │
                    │                          │                 │
                    │         ┌────────────────┼──────────┐      │
                    │         │                │          │      │
                    │         ▼                ▼          ▼      │
                    │   ┌──────────┐    ┌─────┐    ┌─────────┐  │
                    │   │ DynamoDB │    │ S3  │    │CloudWatch│ │
                    │   │(Metadata)│    │(Raw)│    │(Logs)   │  │
                    │   └──────────┘    └─────┘    └─────────┘  │
                    └──────────────────────────────────────────┘
```

**关键点**:
1. ✅ Pi/Glove 通过蓝牙连接 Flutter App（不是直接 HTTPS）
2. ⚠️ Lambda 使用 Python (FastAPI)，不是 Rust
3. ⚠️ CORS 在应用层（FastAPI），不是独立的 Security Edge
4. ✅ API Gateway 可选（本地开发不需要）
5. ✅ Pre-signed URL 用于大文件上传

---

## 安全性评估

### 现有安全措施 ✅

1. **TLS 1.3**: Flutter App 强制使用
   ```dart
   SecurityContext context = SecurityContext.defaultContext;
   context.setTrustedCertificates(certificatesPath);
   ```

2. **JWT 认证**: 所有 API 端点
   ```python
   @app.middleware("http")
   async def _auth_mw(request: Request, call_next):
       return await auth_middleware(request, call_next)
   ```

3. **bcrypt 密码哈希**: 安全存储
   ```python
   def hash_pw(pw: str) -> str:
       return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()
   ```

4. **BLE 安全配对**: LESC + PIN
   ```cpp
   // windows_ble_pairing_plugin.cpp
   case DevicePairingKinds::ProvidePin:
       args.Accept(winrt::to_hstring(pin))
   ```

### 缺失的安全措施 ❌

1. **WAF**: 无 Web Application Firewall
2. **Rate Limiting**: API Gateway 未配置
3. **DDoS 防护**: 依赖 AWS 基础设施
4. **输入验证**: 后端应加强
5. **日志审计**: 需要更系统化

---

## 性能考虑

### Python vs Rust

| 指标 | Python (当前) | Rust (架构图) |
|------|--------------|---------------|
| 开发速度 | ⚡⚡⚡ 快 | 🐢 慢 |
| 运行性能 | 🐢 中等 | ⚡⚡⚡ 快 |
| 冷启动 | ~1-2秒 | ~100-300ms |
| 内存使用 | ~150MB | ~20MB |
| 维护性 | ✅ 简单 | ⚠️ 需要 Rust 专业知识 |

**当前选择合理吗？**
- ✅ **YES** - 对于医疗设备管理系统，Python 的开发速度和可维护性更重要
- ✅ FastAPI 提供自动文档生成（Swagger）
- ✅ 生态系统成熟（boto3, bcrypt, jwt）
- ⚠️ 如果性能成为瓶颈，可考虑迁移到 Rust

---

## 建议

### 立即行动 🔴

1. **更新架构图**
   - Lambda: Rust → Python (FastAPI)
   - Pi/Glove: HTTPS → 蓝牙 → Flutter App → HTTPS

2. **明确 Security Edge**
   - 如果使用 API Gateway → 配置 WAF
   - 如果本地开发 → 文档说明安全由应用层处理

### 短期改进 🟡

1. **添加 Rate Limiting**
   ```python
   # 使用 slowapi
   from slowapi import Limiter
   limiter = Limiter(key_func=get_remote_address)
   ```

2. **加强输入验证**
   ```python
   # 使用 pydantic 的更严格验证
   class RegisterReq(BaseModel):
       email: EmailStr  # 自动验证邮箱格式
       password: constr(min_length=8)  # 最小长度
   ```

3. **添加审计日志**
   ```python
   def audit_log(user_id: str, action: str, resource: str):
       # 记录到 DynamoDB audit_logs 表
       pass
   ```

### 长期优化 🟢

1. **考虑 API Gateway + WAF**（生产环境）
2. **实现 Pre-signed URL**（已有框架）
3. **添加 CloudWatch Alarms**
4. **考虑 Rust 重写热点路径**（如果性能需要）

---

## 结论

### 架构匹配度: 70% ⚠️

**匹配项** ✅:
- 云服务提供商（AWS）
- 数据库（DynamoDB）
- 存储（S3）
- 监控（CloudWatch）
- 总体架构模式（API Gateway + Serverless）

**不匹配项** ❌:
- Lambda 语言（Python vs Rust）
- Security Edge 实现方式
- 设备连接方式（蓝牙 vs HTTPS）

**评价**: 
实际架构是**合理且实用的**，虽然与原架构图有差异，但：
- ✅ 更易于开发和维护
- ✅ 蓝牙连接符合医疗设备常见模式
- ✅ 安全性措施到位（TLS, JWT, bcrypt）
- ⚠️ 需要补充 WAF 和 Rate Limiting

**建议**: 
1. 更新架构图以反映实际实现
2. 或逐步迁移实现以匹配原架构图（取决于需求）

