# MeDUSA 核心功能实现计划 - RBAC 版

**项目目标**: 医疗设备监控系统 - 帕金森病患者震颤监测  
**核心原则**: RBAC (Role-Based Access Control)  
**实现策略**: 最小可用产品 (MVP)，聚焦真实医疗场景

---

## 🎯 项目真实目标

### 核心场景
1. **患者 (Patient)**: 佩戴蓝牙设备 → 采集震颤数据 → 查看自己的数据和报告
2. **医生 (Doctor)**: 查看患者数据 → 分析震颤趋势 → 生成医疗报告
3. **管理员 (Admin)**: 管理用户账户 → 系统监控

### 技术栈
- **设备**: Raspberry Pi + 蓝牙传感器
- **数据**: 实时震颤数据 (加速度计、陀螺仪)
- **通信**: 蓝牙 BLE → Flutter App → Cloud API

---

## 🔐 RBAC 角色定义

### 角色矩阵

| 功能 | Patient | Doctor | Admin |
|------|---------|--------|-------|
| **认证** |
| 注册/登录 | ✅ | ✅ | ✅ |
| 修改自己密码 | ✅ | ✅ | ✅ |
| **设备管理** |
| 扫描蓝牙设备 | ✅ | ✅ | ❌ |
| 连接设备 | ✅ | ✅ | ❌ |
| 查看自己的设备 | ✅ | ❌ | ❌ |
| 查看所有设备 | ❌ | ✅ | ✅ |
| **数据采集** |
| 上传震颤数据 | ✅ | ❌ | ❌ |
| 查看自己的数据 | ✅ | ❌ | ❌ |
| 查看患者数据 | ❌ | ✅ | ✅ |
| **患者管理** |
| 查看患者列表 | ❌ | ✅ | ✅ |
| 查看患者详情 | ❌ | ✅ | ✅ |
| 添加患者备注 | ❌ | ✅ | ❌ |
| **报告** |
| 查看自己的报告 | ✅ | ❌ | ❌ |
| 生成患者报告 | ❌ | ✅ | ❌ |
| 查看所有报告 | ❌ | ❌ | ✅ |
| **用户管理** |
| 查看所有用户 | ❌ | ❌ | ✅ |
| 修改用户角色 | ❌ | ❌ | ✅ |
| 删除用户 | ❌ | ❌ | ✅ |

---

## 📋 MVP 功能清单

### ✅ Phase 1: 核心认证和数据流 (已完成)

#### 1.1 认证系统 ✅
- ✅ 用户注册 (带角色)
- ✅ 用户登录
- ✅ JWT Token (包含角色信息)
- ✅ 密码重置
- ✅ 邮件验证

#### 1.2 基础数据 ✅
- ✅ 姿态数据上传 (Poses)
- ✅ 姿态数据查询
- ✅ 文件上传 (S3)

---

### 🔴 Phase 2: 设备和患者管理 (高优先级)

#### 2.1 设备管理 API ⭐⭐⭐⭐⭐

**为什么重要**: 追踪设备-患者绑定关系，确保数据来源可靠

**数据模型**:
```python
class Device:
    id: str                    # 设备ID (自动生成)
    macAddress: str            # MAC地址 (唯一标识)
    name: str                  # 设备名称
    type: str                  # 设备类型 (默认 "tremor_sensor")
    patientId: str | None      # 绑定的患者ID
    status: str                # online, offline, error
    batteryLevel: int          # 电池电量 (0-100)
    firmwareVersion: str       # 固件版本
    lastSeen: datetime         # 最后在线时间
    createdAt: datetime
    updatedAt: datetime
```

**API 端点**:
```python
# 患者端点
POST   /api/v1/devices                    # 注册设备 (Patient)
GET    /api/v1/devices/my                 # 查看我的设备 (Patient)
PUT    /api/v1/devices/{id}               # 更新设备状态 (Patient)
DELETE /api/v1/devices/{id}               # 解绑设备 (Patient)

# 医生/管理员端点
GET    /api/v1/devices                    # 查看所有设备 (Doctor, Admin)
GET    /api/v1/devices/{id}               # 查看设备详情 (Doctor, Admin)
GET    /api/v1/patients/{patientId}/devices  # 查看患者设备 (Doctor, Admin)
```

**RBAC 规则**:
- `Patient`: 只能管理自己的设备
- `Doctor`: 可以查看所有患者的设备
- `Admin`: 可以查看和管理所有设备

**DynamoDB 表设计**:
```yaml
TableName: medusa-devices-prod
BillingMode: PAY_PER_REQUEST
AttributeDefinitions:
  - AttributeName: id
    AttributeType: S
  - AttributeName: macAddress
    AttributeType: S
  - AttributeName: patientId
    AttributeType: S
KeySchema:
  - AttributeName: id
    KeyType: HASH
GlobalSecondaryIndexes:
  - IndexName: macAddress-index
    KeySchema:
      - AttributeName: macAddress
        KeyType: HASH
    Projection:
      ProjectionType: ALL
  - IndexName: patientId-index
    KeySchema:
      - AttributeName: patientId
        KeyType: HASH
    Projection:
      ProjectionType: ALL
```

**工作量**: 2 天

---

#### 2.2 患者列表和详情 API ⭐⭐⭐⭐⭐

**为什么重要**: 医生需要查看和管理患者，这是核心医疗场景

**数据模型**:
```python
class PatientProfile:
    userId: str                # 用户ID (关联到 Users 表)
    doctorId: str              # 负责医生ID
    diagnosis: str             # 诊断 (如 "Parkinson's Disease")
    severity: str              # 严重程度 (mild, moderate, severe)
    notes: str                 # 医生备注
    createdAt: datetime
    updatedAt: datetime
```

**API 端点**:
```python
# 医生端点
GET    /api/v1/patients                   # 获取我的患者列表 (Doctor)
GET    /api/v1/patients/{userId}          # 获取患者详情 (Doctor)
PUT    /api/v1/patients/{userId}/notes    # 更新患者备注 (Doctor)

# 管理员端点
GET    /api/v1/admin/patients             # 获取所有患者 (Admin)

# 患者端点
GET    /api/v1/me/profile                 # 查看自己的患者档案 (Patient)
```

**RBAC 规则**:
- `Patient`: 只能查看自己的档案
- `Doctor`: 只能查看自己负责的患者
- `Admin`: 可以查看所有患者

**DynamoDB 表设计**:
```yaml
TableName: medusa-patient-profiles-prod
BillingMode: PAY_PER_REQUEST
AttributeDefinitions:
  - AttributeName: userId
    AttributeType: S
  - AttributeName: doctorId
    AttributeType: S
KeySchema:
  - AttributeName: userId
    KeyType: HASH
GlobalSecondaryIndexes:
  - IndexName: doctorId-index
    KeySchema:
      - AttributeName: doctorId
        KeyType: HASH
    Projection:
      ProjectionType: ALL
```

**工作量**: 2 天

---

#### 2.3 增强姿态数据 API ⭐⭐⭐⭐

**为什么重要**: 姿态数据是核心医疗数据，需要更好的查询和分析

**增强功能**:
```python
# 现有端点增强
GET /api/v1/poses?patientId={id}&startDate={date}&endDate={date}&limit={n}
    # 添加日期范围筛选和限制

# 新增端点
GET /api/v1/poses/{poseId}                # 获取单个姿态数据
GET /api/v1/poses/statistics              # 统计分析 (按日期聚合)
    # 返回: 平均震颤强度、趋势、异常检测
```

**RBAC 规则**:
- `Patient`: 只能查看自己的数据
- `Doctor`: 可以查看患者的数据 (需要是负责医生)
- `Admin`: 可以查看所有数据

**工作量**: 1 天

---

### 🟡 Phase 3: 报告系统 (中优先级)

#### 3.1 简化报告系统 ⭐⭐⭐

**为什么重要**: 医生需要生成患者报告，但不需要复杂的模板系统

**数据模型**:
```python
class Report:
    id: str
    patientId: str
    doctorId: str
    title: str
    type: str                  # daily, weekly, monthly
    startDate: datetime
    endDate: datetime
    summary: str               # 文本摘要
    statistics: dict           # JSON: 平均震颤、趋势等
    fileKey: str | None        # S3 PDF 文件 (可选)
    createdAt: datetime
```

**API 端点**:
```python
# 医生端点
POST   /api/v1/reports                    # 生成报告 (Doctor)
GET    /api/v1/reports                    # 获取我的报告列表 (Doctor)
GET    /api/v1/reports/{id}               # 获取报告详情 (Doctor)

# 患者端点
GET    /api/v1/me/reports                 # 查看我的报告 (Patient)
GET    /api/v1/me/reports/{id}            # 查看报告详情 (Patient)
```

**RBAC 规则**:
- `Patient`: 只能查看自己的报告
- `Doctor`: 可以生成和查看患者报告
- `Admin`: 可以查看所有报告

**工作量**: 2 天

---

### 🟢 Phase 4: 管理功能 (低优先级)

#### 4.1 用户管理 ⭐⭐

**为什么重要**: 管理员需要管理用户账户

**API 端点**:
```python
# 管理员端点
GET    /api/v1/admin/users                # 获取所有用户
PUT    /api/v1/admin/users/{id}/role      # 修改用户角色
PUT    /api/v1/admin/users/{id}/status    # 启用/禁用用户
DELETE /api/v1/admin/users/{id}           # 删除用户
```

**RBAC 规则**:
- 仅 `Admin` 可访问

**工作量**: 1 天

---

## ❌ 不实现的功能 (超出 MVP 范围)

### 1. 消息系统 ❌
**原因**: 
- 医患沟通可以通过邮件或其他渠道
- 实现复杂度高 (需要 WebSocket)
- 不是核心医疗功能

### 2. 症状记录 ❌
**原因**:
- 震颤数据已经通过设备自动采集
- 手动记录症状不是核心功能
- 可以在报告中添加备注字段替代

### 3. 设置管理 ❌
**原因**:
- 前端可以本地存储用户偏好
- 不需要后端 API

### 4. 复杂的患者 CRUD ❌
**原因**:
- 患者就是用户 (Users 表)
- 只需要患者档案 (PatientProfile) 来存储医疗信息
- 不需要单独的患者表

### 5. 设备配置管理 ❌
**原因**:
- 设备配置通过蓝牙直接完成
- 不需要云端存储配置

---

## 🚀 实现路线图

### Week 1: 设备和患者管理
**目标**: 医生可以查看患者和设备

- [ ] Day 1-2: 设备管理 API
  - [ ] 创建 DynamoDB 表
  - [ ] 实现设备注册和查询
  - [ ] 实现 RBAC 权限检查
  
- [ ] Day 3-4: 患者档案 API
  - [ ] 创建 DynamoDB 表
  - [ ] 实现患者列表和详情
  - [ ] 医生-患者关联

- [ ] Day 5: 增强姿态数据 API
  - [ ] 添加日期筛选
  - [ ] 实现统计分析
  - [ ] RBAC 权限检查

---

### Week 2: 报告系统
**目标**: 医生可以生成患者报告

- [ ] Day 1-2: 报告生成 API
  - [ ] 创建 DynamoDB 表
  - [ ] 实现报告 CRUD
  - [ ] 基础统计计算

- [ ] Day 3-4: 前后端联调
  - [ ] 测试设备管理
  - [ ] 测试患者列表
  - [ ] 测试报告生成

- [ ] Day 5: 优化和文档
  - [ ] 性能优化
  - [ ] API 文档
  - [ ] 部署到生产

---

### Week 3: 管理功能 (可选)
**目标**: 管理员可以管理用户

- [ ] Day 1: 用户管理 API
- [ ] Day 2-3: 测试和修复
- [ ] Day 4-5: 系统优化

---

## 📊 RBAC 实现细节

### 后端权限检查

#### 方法 1: 装饰器 (推荐)
```python
from functools import wraps
from fastapi import HTTPException, Request

def require_role(*allowed_roles):
    """RBAC 装饰器"""
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            claims = getattr(request.state, "claims", {})
            user_role = claims.get("role")
            
            if user_role not in allowed_roles:
                raise HTTPException(
                    403, 
                    detail={
                        "code": "FORBIDDEN",
                        "message": f"Role '{user_role}' not allowed. Required: {allowed_roles}"
                    }
                )
            
            return await func(request, *args, **kwargs)
        return wrapper
    return decorator

# 使用示例
@app.get("/api/v1/patients")
@require_role("doctor", "admin")
async def get_patients(request: Request):
    claims = request.state.claims
    user_id = claims["sub"]
    user_role = claims["role"]
    
    if user_role == "doctor":
        # 医生只能看自己的患者
        patients = db.get_patients_by_doctor(user_id)
    else:
        # 管理员可以看所有患者
        patients = db.get_all_patients()
    
    return {"patients": patients}
```

#### 方法 2: 资源所有权检查
```python
@app.get("/api/v1/devices/my")
@require_role("patient")
async def get_my_devices(request: Request):
    claims = request.state.claims
    user_id = claims["sub"]
    
    # 患者只能查看自己的设备
    devices = db.get_devices_by_patient(user_id)
    return {"devices": devices}

@app.get("/api/v1/devices/{device_id}")
@require_role("patient", "doctor", "admin")
async def get_device(device_id: str, request: Request):
    claims = request.state.claims
    user_id = claims["sub"]
    user_role = claims["role"]
    
    device = db.get_device(device_id)
    if not device:
        raise HTTPException(404, detail="Device not found")
    
    # 权限检查
    if user_role == "patient":
        # 患者只能查看自己的设备
        if device["patientId"] != user_id:
            raise HTTPException(403, detail="Access denied")
    elif user_role == "doctor":
        # 医生可以查看患者的设备
        patient = db.get_patient_profile(device["patientId"])
        if patient["doctorId"] != user_id:
            raise HTTPException(403, detail="Access denied")
    # Admin 可以查看所有设备
    
    return device
```

---

### 前端权限控制

#### 已有组件
```dart
// lib/shared/widgets/permission_widget.dart
PermissionWidget(
  allowedRoles: ['doctor', 'admin'],
  child: ElevatedButton(
    onPressed: () => _generateReport(),
    child: Text('Generate Report'),
  ),
  fallback: Text('You do not have permission to generate reports'),
)
```

#### 路由保护
```dart
// lib/core/router/app_router.dart
GoRoute(
  path: '/patients',
  name: 'patients',
  pageBuilder: (context, state) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (authState.user.role == 'doctor' || authState.user.role == 'admin') {
        return NoTransitionPage(child: PatientsPage());
      }
    }
    return NoTransitionPage(child: UnauthorizedPage());
  },
)
```

---

## 📝 数据库表总结

### 现有表 ✅
1. `medusa-users-prod` - 用户表
2. `medusa-poses-prod` - 姿态数据
3. `medusa-refresh-tokens-prod` - 刷新令牌

### 新增表 (Phase 2-4)
4. `medusa-devices-prod` - 设备管理
5. `medusa-patient-profiles-prod` - 患者档案
6. `medusa-reports-prod` - 报告

**总计**: 6 个表 (简洁高效)

---

## 🎯 成功标准

### Phase 2 完成标准
- [ ] 患者可以注册设备并查看自己的设备
- [ ] 医生可以查看患者列表和设备
- [ ] 姿态数据可以按日期筛选
- [ ] RBAC 权限正确执行 (403 错误测试通过)

### Phase 3 完成标准
- [ ] 医生可以生成患者报告
- [ ] 患者可以查看自己的报告
- [ ] 报告包含基础统计信息

### Phase 4 完成标准
- [ ] 管理员可以管理用户
- [ ] 管理员可以修改用户角色

---

## 💡 关键设计决策

### 1. 患者 = 用户
**决策**: 不创建单独的患者表，患者就是 `role=patient` 的用户  
**原因**: 简化架构，避免数据冗余

### 2. 医生-患者关联
**决策**: 在 `PatientProfile` 中存储 `doctorId`  
**原因**: 一个患者对应一个负责医生 (简化版)

### 3. 设备绑定
**决策**: 设备通过 `patientId` 绑定到患者  
**原因**: 一个设备对应一个患者 (医疗设备场景)

### 4. 报告存储
**决策**: 报告元数据存 DynamoDB，PDF 文件存 S3  
**原因**: 结构化数据和文件分离存储

---

## 🚀 立即开始

**推荐**: 从 Phase 2.1 设备管理 API 开始

**原因**:
1. ✅ 设备管理是核心功能
2. ✅ 前端已有设备扫描和连接 UI
3. ✅ 可以立即看到效果
4. ✅ 为后续功能打好基础

**下一步**: 
1. 创建 `medusa-devices-prod` DynamoDB 表
2. 实现设备注册 API
3. 实现 RBAC 权限检查
4. 前后端联调测试

---

**准备好开始了吗？** 🚀

