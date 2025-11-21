# MeDUSA 数据流程完整分析

## 📊 当前数据流程状态

### 1. Pi设备发送数据格式（推测）
```json
{
  "x": [0.123, 0.145, ...],  // 500个采样点
  "y": [0.234, 0.256, ...],
  "z": [0.345, 0.367, ...],
  "temperature": 25.5,
  "sequence": 123
}
```

### 2. AWS IoT规则 (`medusa_sensor_to_lambda`)
**Topic Pattern**: `medusa/+/sensor/data`

**SQL查询**:
```sql
SELECT 
  timestamp() as timestamp,
  clientId() as device_id,
  x as accel_x,  -- ❌ 这里会直接传递整个数组
  y as accel_y,  -- ❌ 这里会直接传递整个数组
  z as accel_z,  -- ❌ 这里会直接传递整个数组
  magnitude,
  temperature,
  sequence,
  (timestamp() / 1000) + 2592000 as ttl
FROM 'medusa/+/sensor/data'
WHERE x <> Null 
  AND y <> Null 
  AND z <> Null
  AND magnitude <> Null
```

**问题**: 
- SQL规则没有展开数组，直接传递给Lambda
- `magnitude`字段在Pi数据中可能不存在（需要计算）

### 3. medusa-enrich-sensor-data Lambda
**期望输入**:
```python
{
    'device_id': 'DEV-002',
    'timestamp': 1763435526,
    'accel_x': 0.123,  # ❌ 期望单值，实际收到数组
    'accel_y': 0.234,  # ❌ 期望单值，实际收到数组
    'accel_z': 0.345,  # ❌ 期望单值，实际收到数组
    'magnitude': 0.456,
    'sequence': 123,
    'ttl': 1766027526
}
```

**实际写入DynamoDB**:
```python
{
    'device_id': 'DEV-002',
    'timestamp': 1763435526,
    'accel_x': [0.123, 0.145, ...],  # ✅ 实际存储的是数组
    'accel_y': [0.234, 0.256, ...],  # ✅ 实际存储的是数组
    'accel_z': [0.345, 0.367, ...],  # ✅ 实际存储的是数组
    'magnitude': [calculated],       # ✅ 可能也是数组
    'patient_id': 'PAT-002'  # ❌ 错误的patient_id（应该是usr_694c4028）
}
```

### 4. medusa-sensor-data 表
**实际存储的数据结构**:
```json
{
  "device_id": "DEV-002",
  "timestamp": 1763435526,
  "accelerometer_x": [0.0651, 0.0798, ...],  // 500个值
  "accelerometer_y": [0.5215, 0.5282, ...],  // 500个值
  "accelerometer_z": [0.9419, 0.8935, ...],  // 500个值
  "sampling_rate": 100,
  "battery_level": 85,
  "patient_id": "PAT-002",  // ❌ 错误的ID
  "device_status": "active"
}
```

**Schema (Actual)**:
- Primary Key: `device_id` (HASH)
- Sort Key: `timestamp` (RANGE)

### 5. medusa-process-sensor-data Lambda
**期望**:
- 从`medusa-sensor-data`读取数据
- 提取加速度计数组
- 计算震颤特征
- 写入`medusa-tremor-analysis`

**当前状态**:
- ✅ 代码已更新以处理数组格式
- ❌ 未部署（package size > 50MB due to numpy/scipy）

### 6. medusa-tremor-analysis 表
**目标数据结构**:
```json
{
  "patient_id": "usr_694c4028",  // ✅ 正确的ID
  "timestamp": "2025-11-21T04:24:25.590960Z",
  "device_id": "DEV-002",
  "rms_value": 0.3969,
  "dominant_frequency": 8.93,
  "tremor_power": 3471.69,
  "total_power": 5487.1,
  "tremor_index": 0.6327,
  "tremor_score": 63.27,
  "is_parkinsonian": false,
  "signal_quality": 0.95,
  "ttl": 1771493065
}
```

**当前状态**:
- ✅ 1,151条记录已通过批处理脚本生成
- ✅ 所有记录使用正确的`patient_id: usr_694c4028`

### 7. QueryTremorData Lambda (API Gateway)
**响应格式**:
```json
{
  "success": true,
  "data": [
    {
      "patient_id": "usr_694c4028",
      "timestamp": "2025-11-21T04:24:25.590960Z",
      "device_id": "DEV-002",
      "rms": 0.3969,  // ✅ 字段已规范化（rms_value → rms）
      "dominant_frequency": 8.93,
      "tremor_power": 3471.69,
      "total_power": 5487.1,
      "tremor_index": 0.6327,
      "tremor_score": 63.27,
      "is_parkinsonian": false,
      "signal_quality": 0.95
    }
  ],
  "count": 1151
}
```

**状态**: ✅ 已部署，字段映射正确

### 8. Flutter前端
**TremorAnalysis模型期望**:
```dart
{
  device_id: String,
  timestamp: String (ISO8601),
  rms: double,  // ✅ 支持 rms_value 或 rms
  dominant_frequency: double,  // ✅ 支持多种命名
  tremor_power: double,
  tremor_index: double,  // 0-1 范围
  tremor_score: double,  // 0-100 范围
  is_parkinsonian: bool,
  signal_quality: double
}
```

**状态**: ✅ 已修复计算逻辑，支持所有字段

---

## 🚨 核心问题

### 问题 1: Pi数据格式不匹配
**症状**: Pi发送数组，但IoT规则和enrich Lambda期望单值

**可能原因**:
1. Pi发送批量数据（500个采样点/消息）以减少网络传输
2. IoT规则没有正确处理数组展开
3. Enrich Lambda直接存储了数组（意外地"正确"）

**解决方案选项**:
- **选项A**: 修改Pi代码，每次只发送1个采样点
  - 优点：简单，匹配现有IoT规则
  - 缺点：网络开销大（500倍消息量）
  
- **选项B**: 修改IoT规则和enrich Lambda，正确处理数组
  - 优点：高效，减少网络传输
  - 缺点：需要重写Lambda逻辑

- **选项C** (当前实际发生的): 保持现状，在process Lambda中处理数组
  - 优点：数据已经在存储中
  - 缺点：不符合原始设计

### 问题 2: patient_id 硬编码错误
**症状**: 所有sensor data显示`patient_id: "PAT-002"`，但设备注册表显示`DEV-002 → usr_694c4028`

**原因**: 
- Enrich Lambda查询`medusa-device-patient-mapping`表
- 但实际设备注册在`medusa-devices-prod`表
- 两个表的映射不一致

**解决方案**:
```python
# 修改 enrich Lambda 查询设备注册表
devices_table = dynamodb.Table('medusa-devices-prod')
device_record = devices_table.get_item(Key={'id': device_id})
patient_id = device_record['Item'].get('patientId', 'UNASSIGNED')
```

### 问题 3: process-sensor-data Lambda 部署失败
**症状**: Package size > 50MB (numpy + scipy)

**解决方案选项**:
- **选项A**: 使用Lambda Layer
- **选项B**: 使用容器映像部署
- **选项C**: 上传到S3再部署
- **选项D** (已完成): 使用独立脚本批量处理历史数据

---

## ✅ 已完成的工作

1. ✅ **QueryTremorData Lambda**: 字段规范化（rms_value → rms）
2. ✅ **GetTremorStatistics Lambda**: 添加DynamoDB初始化
3. ✅ **Flutter TremorAnalysis模型**: 修复tremor_index计算
4. ✅ **批量处理脚本**: 生成1,151条真实Pi数据分析记录
5. ✅ **数据验证**: 确认API响应格式与Flutter期望匹配

---

## 🔄 待完成工作

### 高优先级

1. **修复enrich Lambda的patient_id查询**
   - 从`medusa-devices-prod`表查询而非`medusa-device-patient-mapping`
   - 确保新数据使用正确的patient_id

2. **验证Pi数据发送格式**
   - 检查Pi实际发送的MQTT消息格式
   - 确认是单值还是数组

3. **前端测试**
   - 在Flutter app中测试数据显示
   - 确认图表渲染正常

### 中优先级

4. **部署process-sensor-data Lambda**
   - 使用Lambda Layer或S3上传
   - 设置定时触发处理新数据

5. **清理历史错误数据**
   - 可选：删除patient_id="PAT-002"的旧数据

### 低优先级

6. **优化IoT规则**
   - 如果Pi发送数组，正确处理展开逻辑
   - 添加数据验证

---

## 📝 推荐行动计划

### 立即执行 (今天)
1. 修复`medusa-enrich-sensor-data` Lambda的patient_id查询逻辑
2. 部署更新后的enrich Lambda
3. 在Flutter app中测试数据显示

### 短期 (本周)
4. 检查Pi代码，确认MQTT消息格式
5. 如需要，更新IoT规则处理数组
6. 部署process-sensor-data Lambda (使用Lambda Layer)

### 长期 (下周+)
7. 添加数据质量监控
8. 设置自动化测试
9. 文档化完整数据流程

---

## 🎯 成功标准

数据流程完全正常的标志：

1. ✅ Pi发送数据 → `medusa-sensor-data`（正确的patient_id）
2. ✅ 自动触发 → `process-sensor-data` Lambda
3. ✅ 生成分析结果 → `medusa-tremor-analysis`
4. ✅ API返回数据 → 正确的字段映射
5. ✅ Flutter显示 → 图表和统计数据正常

当前状态：**80%完成** (历史数据已处理，实时流程待修复)
