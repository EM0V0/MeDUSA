## MeDUSA Tremor数据显示问题 - 完整分析报告

### 执行时间
2025-11-21

### 问题描述
已成功配对设备后的patient的medusa-tremor-analysis数据无法在前端显示

---

## 🔍 问题分析结果

### 发现的问题

#### 1. Lambda函数字段映射不匹配 ⚠️

**文件**: `lambda_functions/query_tremor_data.py`

**问题**:
- DynamoDB存储的字段名: `rms_value`
- 前端期望的字段名: `rms`  
- 缺少 `tremor_score` 字段(只返回 `tremor_index`)

**修复**:
```python
# 在query_tremor_data.py中添加字段标准化
normalized_item = {
    'patient_id': item.get('patient_id'),
    'timestamp': item.get('timestamp'),
    'device_id': item.get('device_id'),
    'rms': item.get('rms_value', item.get('rms', 0)),  # ✓ 映射rms_value到rms
    'dominant_frequency': item.get('dominant_frequency', 0),
    'tremor_index': item.get('tremor_index', 0),
    'tremor_score': item.get('tremor_score', float(item.get('tremor_index', 0)) * 100),  # ✓ 添加tremor_score
    'is_parkinsonian': item.get('is_parkinsonian', False),
    # ... 其他字段
}
```

**状态**: ✅ 已部署到AWS Lambda

---

#### 2. get_tremor_statistics.py缺少DynamoDB初始化 ⚠️

**文件**: `lambda_functions/get_tremor_statistics.py`

**问题**:
函数中使用了`table.query()`但没有初始化`table`变量

**修复**:
```python
import boto3
from boto3.dynamodb.conditions import Key

# ✓ 添加DynamoDB初始化
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medusa-tremor-analysis')
```

**状态**: ✅ 已部署到AWS Lambda

---

#### 3. 前端Model的tremor_index计算错误 ⚠️

**文件**: `meddevice-app-flutter-main/lib/features/patients/data/models/tremor_analysis.dart`

**问题**:
```dart
// ❌ 错误: tremorIndex应该是0-1范围,但被赋值为0-100的score
final tremorIndex = tremorScoreVal;  // tremorScoreVal是0-100
```

**修复**:
```dart
// ✓ 正确分离两个变量
double tremorIndexVal = 0.0;  // 0-1 range
double tremorScoreVal = 0.0;  // 0-100 range

if (json['tremor_index'] != null) {
  tremorIndexVal = _parseDouble(json['tremor_index']);
  if (tremorIndexVal > 1.0) {
    tremorIndexVal = tremorIndexVal / 100.0;  // 归一化
  }
}

if (json['tremor_score'] != null) {
  tremorScoreVal = _parseDouble(json['tremor_score']);
} else {
  tremorScoreVal = tremorIndexVal * 100;  // 从index计算
}

// 支持rms_value字段
final rmsValue = _parseDouble(json['rms_value'] ?? json['rms']);
```

**状态**: ✅ 已修改

---

#### 4. 数据不一致 - 根本原因 🔴

**最关键的问题**: 数据库中的patient_id不匹配

**详细分析**:

1. **设备注册表** (`medusa-devices-prod`):
```json
{
  "id": "DEV-002",
  "patientId": "usr_694c4028"  // ✓ 当前正确的用户ID
}
```

2. **传感器数据表** (`medusa-sensor-data`):
```json
{
  "device_id": "DEV-002",
  "patient_id": "PAT-002"  // ❌ 旧的测试patient_id
}
```

3. **Tremor分析表** (`medusa-tremor-analysis`):
```json
{
  "patient_id": "PAT-002",  // ❌ 从传感器数据继承的错误ID
  "device_id": "DEV-002"
}
```

**为什么会出现这个问题**:
- 传感器数据是在设备重新分配给 `usr_694c4028` 之前写入的
- 这些历史数据仍然带有旧的 `PAT-002` ID
- 当前端使用 `usr_694c4028` 查询时,找不到任何数据

**查询验证**:
```bash
# 查询usr_694c4028的数据 - 返回0条记录
aws dynamodb query --table-name medusa-tremor-analysis \
  --key-condition-expression "patient_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "usr_694c4028"}}'
# 结果: {"Items": [], "Count": 0}

# 查询PAT-002的数据 - 返回多条记录  
aws dynamodb query --table-name medusa-tremor-analysis \
  --key-condition-expression "patient_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "PAT-002"}}'
# 结果: {"Items": [...], "Count": 20}
```

---

## ✅ 已实施的修复

### 1. Backend修复
- ✅ 更新 `QueryTremorData` Lambda函数
  - 添加字段名标准化
  - 映射 `rms_value` → `rms`
  - 计算并添加 `tremor_score` 字段
  
- ✅ 更新 `GetTremorStatistics` Lambda函数
  - 添加DynamoDB初始化代码
  
- ✅ 部署到AWS
  ```bash
  aws lambda update-function-code --function-name QueryTremorData ...
  aws lambda update-function-code --function-name GetTremorStatistics ...
  ```

### 2. Frontend修复
- ✅ 更新 `TremorAnalysis.fromJson()` 方法
  - 正确处理 `rms_value` 和 `rms` 字段
  - 分离 `tremor_index` (0-1) 和 `tremor_score` (0-100)
  - 添加字段值验证和归一化

---

## 🔄 需要的后续操作

### 方案 A: 等待新数据生成 (推荐)
当设备DEV-002发送新的传感器数据时:
1. `medusa-sensor-data` 会存储新数据,带有正确的 `patient_id`: `usr_694c4028`
2. `process_sensor_data` Lambda会从设备注册表读取正确的patientId
3. 生成的tremor分析数据会有正确的 `patient_id`: `usr_694c4028`
4. 前端就能正常查询和显示数据

### 方案 B: 手动触发数据处理
如果有最近的传感器数据,可以手动触发处理:

```bash
# 1. 检查是否有DEV-002的传感器数据
aws dynamodb scan --table-name medusa-sensor-data \
  --filter-expression "device_id = :did" \
  --expression-attribute-values '{":did": {"S": "DEV-002"}}'

# 2. 手动触发处理Lambda
aws lambda invoke --function-name medusa-process-sensor-data \
  --payload '{"device_id": "DEV-002"}' \
  response.json
```

### 方案 C: 更新历史数据 (不推荐)
可以迁移PAT-002的数据到usr_694c4028,但这会破坏数据完整性。

---

## 📊 测试验证

### Lambda函数测试
```bash
# 测试QueryTremorData (使用旧数据验证字段映射)
aws lambda invoke --function-name QueryTremorData \
  --payload '{"queryStringParameters": {"patient_id": "PAT-002", "limit": "2"}}' \
  response.json

# 返回的数据结构 ✓
{
  "success": true,
  "data": [{
    "patient_id": "PAT-002",
    "timestamp": "2025-11-17T22:12:06.160809Z",
    "device_id": "DEV-002",
    "rms": 0.1531,  // ✓ 正确映射
    "dominant_frequency": 0.8,
    "tremor_index": 0.0265,
    "tremor_score": 2.65,  // ✓ 正确添加
    "is_parkinsonian": false,
    "signal_quality": 0.92
  }],
  "count": 2
}
```

---

## 📝 总结

### 问题根源
前端无法显示tremor数据的根本原因是**数据库中patient_id不一致**:
- 设备注册表中的patientId: `usr_694c4028` (正确)
- Tremor分析表中的patient_id: `PAT-002` (历史数据)
- 前端查询 `usr_694c4028` 时找不到数据

### 已修复的技术问题
1. ✅ Lambda函数字段映射
2. ✅ DynamoDB初始化缺失
3. ✅ 前端数据模型字段解析

### 下一步
等待设备发送新的传感器数据,或手动触发数据处理生成新的tremor分析记录。新数据会使用正确的patient_id (`usr_694c4028`),前端就能正常显示了。

---

## 🎯 建议

1. **数据一致性**: 在设备重新分配时,考虑清理或更新相关的传感器数据
2. **字段命名**: 统一后端和前端的字段命名约定(建议使用snake_case或camelCase,保持一致)
3. **数据验证**: 在Lambda函数中添加patient_id验证,确保数据一致性
4. **监控告警**: 添加数据不一致的监控和告警机制
