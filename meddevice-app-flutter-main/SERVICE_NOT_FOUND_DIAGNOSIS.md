# 🔧 WiFi Helper服务未找到 - 诊断指南

## 问题现状

✅ **配对成功** - Windows和Raspberry Pi已经配对  
✅ **连接成功** - BLE连接已建立  
✅ **发现了5个服务** - GATT服务发现工作正常  
❌ **WiFi Helper服务未找到** - 应用期望的UUID不在发现的服务中

## 服务UUID检查

**应用期望的UUID**:
```
c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de
```

**包含的特征UUID**:
- SSID: `c0de0001-7e1a-4f83-bf3a-0c0ffee0c0de`
- PSK: `c0de0002-7e1a-4f83-bf3a-0c0ffee0c0de`
- Control: `c0de0003-7e1a-4f83-bf3a-0c0ffee0c0de`
- Status: `c0de0004-7e1a-4f83-bf3a-0c0ffee0c0de`

## 诊断步骤

### 1. 检查应用日志

运行应用后，查找这些日志：

```
[WinBleWiFi] 📋 Listing all discovered services:
[WinBleWiFi]   Service 0: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
[WinBleWiFi]   Service 1: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
...
```

**查看发现的UUID列表，看是否有 `c0de0000` 开头的服务**

### 2. 检查Raspberry Pi服务状态

SSH到Raspberry Pi:

```bash
# 检查WiFi Helper服务是否运行
sudo systemctl status medusa_wifi_helper

# 查看详细日志
sudo journalctl -u medusa_wifi_helper -n 100 --no-pager

# 检查BlueZ是否正常
sudo systemctl status bluetooth

# 查看蓝牙设备状态
bluetoothctl
show
```

**关键信息**:
- `medusa_wifi_helper` 应该是 `active (running)`
- 日志中应该有 "GATT server registered" 或类似消息
- BlueZ应该是 `active (running)`

### 3. 验证GATT服务器配置

在Raspberry Pi上：

```bash
# 查看GATT服务器配置文件
cat /path/to/medusa_wifi_helper/gatt_server.py  # 或对应文件

# 检查服务注册代码
grep -r "c0de0000" /path/to/medusa_wifi_helper/
```

**验证**:
- 服务UUID是否正确：`c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de`
- 服务是否已注册到BlueZ
- 是否有权限/访问控制问题

### 4. 使用bluetoothctl验证

在**另一台Linux机器**或使用Windows的`bluetoothctl`：

```bash
bluetoothctl
scan on
# 等待找到MeDUSA-Helper
scan off

# 连接
connect 2C:CF:67:23:E8:5E

# 列出所有服务
menu gatt
list-attributes

# 查找c0de0000开头的UUID
```

### 5. 常见问题

#### 问题A: 服务未注册

**症状**: 只发现了标准BLE服务（GAP、GATT、Device Info等）

**解决**:
```bash
# 重启WiFi Helper服务
sudo systemctl restart medusa_wifi_helper

# 查看是否有注册错误
sudo journalctl -u medusa_wifi_helper -f
```

#### 问题B: UUID大小写/格式问题

**症状**: 服务存在但UUID格式不匹配

**检查**:
- Pi上的UUID是否使用小写？
- 是否有连字符？
- Windows可能返回大写UUID

**应用已处理**: 代码已经标准化为小写且移除连字符

#### 问题C: 权限/配对要求

**症状**: 服务存在但配对后才可见

**Pi端配置**:
```python
# 在GATT服务器中，服务可能需要配对
# 检查服务定义:
service = {
    'UUID': 'c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de',
    'primary': True,
    # 是否需要配对？
    'Characteristics': [...]
}
```

#### 问题D: BlueZ版本不兼容

**检查BlueZ版本**:
```bash
bluetoothctl --version
```

**要求**: BlueZ 5.50+（推荐5.55+）

### 6. 手动测试（使用program.cs的C#版本）

参考之前的 `program.cs`，它能成功读取服务：

```bash
# 在Windows上运行C#测试工具
cd /path/to/program.cs
dotnet run
```

**对比**:
- C#版本能否找到服务？
- 如果能，说明Pi端正常，问题在Flutter/WinBle
- 如果不能，说明Pi端有问题

## 下一步行动

### 立即运行应用并查看日志

```powershell
flutter run -d windows
```

**查找这行**:
```
[WinBleWiFi] 📋 Listing all discovered services:
```

**记录所有UUID，然后对比**:
1. 是否有 `c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de`？
2. 如果没有，有哪些UUID？
3. 是否只有标准服务（0x1800, 0x1801等）？

### 根据结果采取行动

#### 情况1: 完全没有c0de开头的UUID

**原因**: Pi的GATT服务器未运行或未注册服务

**解决**:
```bash
# 在Pi上
sudo systemctl restart medusa_wifi_helper
sudo journalctl -u medusa_wifi_helper -f
# 查看是否有"Service registered"消息
```

#### 情况2: 有c0de但UUID不完全匹配

**原因**: UUID格式或拼写错误

**解决**: 对比Pi的源代码和应用的UUID常量

#### 情况3: 只有标准服务

**原因**: 
- Pi的GATT服务器未启动
- 服务注册失败
- BlueZ配置问题

**解决**:
```bash
# 检查BlueZ配置
cat /etc/bluetooth/main.conf

# 确保GATT缓存已清除
sudo rm -rf /var/lib/bluetooth/*/cache/
sudo systemctl restart bluetooth
```

## 成功标志

当问题解决后，应该看到：

```
[WinBleWiFi] 📋 Listing all discovered services:
[WinBleWiFi]   Service 0: 00001800-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 1: 00001801-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 2: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de  ← 这个！
[WinBleWiFi]   Service 3: ...
[WinBleWiFi] 🔍 Looking for service UUID: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de
[WinBleWiFi]   ✅ MATCH FOUND: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de
[WinBleWiFi] ✅ WiFi Helper service found
```

然后就可以继续写入WiFi凭据了！

## 需要Pi端的信息

为了进一步诊断，请提供：

1. **Pi的服务日志**:
   ```bash
   sudo journalctl -u medusa_wifi_helper -n 100 --no-pager
   ```

2. **BlueZ服务状态**:
   ```bash
   sudo systemctl status bluetooth
   ```

3. **Pi的GATT配置**（如果是Python）:
   ```bash
   cat /path/to/gatt_service_definition.py
   ```

4. **Flutter应用的完整服务列表**（运行应用后）

有了这些信息，我们就能精确定位问题！
