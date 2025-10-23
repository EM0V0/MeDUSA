# 🐛 Bug Fixes - Service Discovery & Pairing Issues

## 修复日期
2025-10-23

## 问题总结

用户报告了两个关键问题：
1. **服务发现失败** - 尽管Raspberry Pi在广播WiFi Helper GATT服务，应用却报告"服务未找到"
2. **PIN不稳定生成** - Raspberry Pi的OLED屏幕不总是显示配对PIN码

## 问题分析

### 问题1: 类型错误导致服务发现失败

**症状：**
```
[WinBleWiFi]   Service 4: Error reading UUID - NoSuchMethodError: Class 'String' has no instance getter 'uuid'.
Receiver: "c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de"
Tried calling: uuid
```

**根本原因：**
- WinBle的`discoverServices()`返回的是**String类型的UUID列表**，不是对象
- 代码错误地尝试访问 `(service as dynamic).uuid`
- 实际上`service`本身就已经是String UUID了

**证据：**
```
Service 4: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de  ← 这个就是WiFi Helper服务！
```
服务确实存在，但类型转换错误导致无法识别。

---

### 问题2: 设备已配对导致Pi不生成PIN

**症状：**
```
[WindowsPairing] Device 2C:CF:67:23:E8:5E paired status: true
[WinBle] ✅ Device already paired
```

**根本原因：**
- Windows和Raspberry Pi之前已经完成配对
- 当设备已配对时，Windows不会再次请求PIN
- Raspberry Pi检测到已配对，也不会在OLED上显示新PIN
- 用户无法重新输入PIN码

**用户需求：**
需要一个"解除配对"功能来清除旧的配对状态，触发新的PIN生成。

---

## 修复方案

### 修复1: 服务UUID类型处理

**文件：** `lib/shared/services/winble_wifi_helper_service.dart`

**修改前：**
```dart
// 错误：假设service是对象，尝试访问.uuid属性
for (var i = 0; i < services.length; i++) {
  try {
    final uuid = (services[i] as dynamic).uuid as String?;
    debugPrint('[WinBleWiFi]   Service $i: ${uuid ?? "unknown"}');
  } catch (e) {
    debugPrint('[WinBleWiFi]   Service $i: Error reading UUID - $e');
  }
}

final hasWiFiService = services.any((service) {
  try {
    final uuid = (service as dynamic).uuid as String?;
    // ... 复杂的null检查和错误处理
  } catch (e) {
    return false;
  }
});
```

**修改后：**
```dart
// 正确：service本身就是String UUID
for (var i = 0; i < services.length; i++) {
  final uuid = services[i] as String;
  debugPrint('[WinBleWiFi]   Service $i: $uuid');
}

final hasWiFiService = services.any((service) {
  // Service is already a String UUID
  final uuid = service as String;
  final normalizedUuid = uuid.toLowerCase().replaceAll('-', '');
  final matches = normalizedUuid == targetUuid;
  
  if (matches) {
    debugPrint('[WinBleWiFi]   ✅ MATCH FOUND: $uuid');
  }
  
  return matches;
});
```

**效果：**
- ✅ 服务UUID正确读取
- ✅ WiFi Helper服务成功识别
- ✅ 可以继续GATT特征读写操作

---

### 修复2: 添加解除配对功能

#### 2.1 在WinBleService中添加unpairDevice方法

**文件：** `lib/shared/services/winble_service.dart`

**新增代码：**
```dart
/// Unpair a device
Future<bool> unpairDevice(String deviceAddress) async {
  try {
    debugPrint('[WinBle] 🔓 Unpairing device $deviceAddress');
    
    _setStatus('Unpairing...');
    
    // Use Windows native unpair
    final success = await WindowsPairingService.unpairDevice(deviceAddress);

    if (success) {
      debugPrint('[WinBle] ✅ Device unpaired successfully');
      _setStatus('Unpaired');
      
      // Clear connected device if it matches
      if (_connectedDeviceAddress == deviceAddress) {
        _connectedDeviceAddress = null;
      }
      
      return true;
    } else {
      debugPrint('[WinBle] ❌ Unpair failed');
      _setStatus('Unpair failed');
      return false;
    }
  } catch (e) {
    debugPrint('[WinBle] ❌ Unpair error: $e');
    _setStatus('Unpair error');
    return false;
  }
}
```

**说明：**
- 使用已有的`WindowsPairingService.unpairDevice()`
- 清理内部连接状态
- 返回成功/失败状态

---

#### 2.2 在WinBleWiFiHelperService中暴露unpair方法

**文件：** `lib/shared/services/winble_wifi_helper_service.dart`

**新增代码：**
```dart
/// Unpair a device to allow fresh pairing with new PIN
/// 
/// This is useful when:
/// - User wants to re-enter PIN code
/// - Raspberry Pi is not generating new PIN (because already paired)
/// - Need to clear old pairing state
/// 
/// [deviceAddress]: BLE device address (MAC) to unpair
/// 
/// Returns: true if unpair succeeds
Future<bool> unpairDevice(String deviceAddress) async {
  try {
    debugPrint('[WinBleWiFi] 🔓 Unpairing device $deviceAddress');
    _lastError = null;
    
    // Call WinBle unpair (which uses WindowsPairingService)
    final success = await _winBle.unpairDevice(deviceAddress);
    
    if (success) {
      // Reset state
      _connectedDeviceAddress = null;
      _isPaired = false;
      
      debugPrint('[WinBleWiFi] ✅ Device unpaired successfully');
      _setStatus('Device unpaired - ready for fresh pairing');
      
      return true;
    } else {
      debugPrint('[WinBleWiFi] ❌ Unpair failed');
      _lastError = 'Failed to unpair device';
      _setStatus('Unpair failed');
      return false;
    }
  } catch (e) {
    debugPrint('[WinBleWiFi] ❌ Unpair error: $e');
    _lastError = e.toString();
    _setStatus('Error unpairing: $e');
    return false;
  }
}
```

---

#### 2.3 在UI中添加"Unpair Device"按钮

**文件：** `lib/features/devices/presentation/pages/wifi_provision_page.dart`

**UI改动：**
```dart
// 在"Connect & Pair"按钮下方添加
if (_isConnected || _isPaired) ...[
  SizedBox(height: 12.h),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _isProvisioning ? null : _unpairDevice,
      icon: Icon(
        Icons.link_off_rounded,
        size: IconUtils.getResponsiveIconSize(IconSizeType.medium, context),
        color: AppColors.warning,
      ),
      label: Text(
        'Unpair Device (to re-enter PIN)',
        style: FontUtils.body(
          context: context,
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.warning, width: 1.5),
        padding: EdgeInsets.symmetric(vertical: 16.h),
      ),
    ),
  ),
],
```

**新增方法：**
```dart
/// Unpair the device to allow fresh pairing with new PIN
Future<void> _unpairDevice() async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unpair Device?'),
      content: const Text(
        'This will remove the current pairing. You\'ll need to enter the PIN again from the Raspberry Pi OLED display when reconnecting.\n\nThis is useful if:\n• You want to re-enter the PIN\n• Pi is not generating a new PIN code',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          child: const Text('Unpair'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() {
    _statusMessage = 'Unpairing device...';
  });

  try {
    debugPrint('[WiFiProvision] Requesting unpair for $_deviceAddress');
    final success = await _wifiService.unpairDevice(_deviceAddress);

    if (success) {
      setState(() {
        _isConnected = false;
        _isPaired = false;
        _statusMessage = 'Device unpaired successfully. You can now connect again with a fresh PIN.';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Device unpaired. Connect again to enter new PIN.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      debugPrint('[WiFiProvision] ✓ Unpair successful');
    } else {
      setState(() {
        _statusMessage = 'Failed to unpair device';
      });
      _showErrorDialog('Could not unpair device. Try removing it manually from Windows Bluetooth settings.');
      debugPrint('[WiFiProvision] ✗ Unpair failed');
    }
  } catch (e) {
    debugPrint('[WiFiProvision] Error during unpair: $e');
    setState(() {
      _statusMessage = 'Error: $e';
    });
    _showErrorDialog('Error unpairing: $e');
  }
}
```

**UI效果：**
- 当设备已连接或已配对时，显示黄色边框的"Unpair Device"按钮
- 点击后弹出确认对话框
- 解除配对成功后，用户可以重新连接并输入新PIN

---

## 测试步骤

### 1. 测试服务发现修复

1. 启动应用并扫描设备
2. 选择MeDUSA-Helper设备
3. 点击"Connect & Pair"
4. 查看日志，应该看到：

```
[WinBleWiFi] 📋 Listing all discovered services:
[WinBleWiFi]   Service 0: 00001800-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 1: 00001801-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 2: 0000180a-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 3: 0000184d-0000-1000-8000-00805f9b34fb
[WinBleWiFi]   Service 4: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de
[WinBleWiFi]   ✅ MATCH FOUND: c0de0000-7e1a-4f83-bf3a-0c0ffee0c0de
[WinBleWiFi] ✅ WiFi Helper service found
```

**预期结果：**
- ✅ 不再有"NoSuchMethodError"
- ✅ 服务UUID正确列出
- ✅ WiFi Helper服务被识别

### 2. 测试解除配对功能

**场景A：设备已配对，Pi不显示PIN**

1. 设备显示"Connected & Paired"状态
2. 应该看到"Unpair Device (to re-enter PIN)"按钮
3. 点击"Unpair"按钮
4. 确认对话框
5. 查看日志：

```
[WiFiProvision] Requesting unpair for 2C:CF:67:23:E8:5E
[WinBleWiFi] 🔓 Unpairing device 2C:CF:67:23:E8:5E
[WindowsPairing] 🔓 Unpairing device: 2C:CF:67:23:E8:5E
[WindowsPairing] ✅ Device unpaired
[WinBle] ✅ Device unpaired successfully
[WinBleWiFi] ✅ Device unpaired successfully
[WiFiProvision] ✓ Unpair successful
```

6. 按钮状态恢复为"Connect & Pair"
7. **再次点击"Connect & Pair"**
8. **Raspberry Pi的OLED应该显示新的6位数PIN**
9. 输入PIN完成配对

**预期结果：**
- ✅ 解除配对成功
- ✅ Pi重新生成并显示PIN
- ✅ 可以重新配对

**场景B：手动验证配对状态**

在PowerShell中检查Windows配对状态：
```powershell
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*MeDUSA*"}
```

解除配对前后，设备应该从列表中消失/重新出现。

---

## 对比program.cs

从用户提供的`program.cs`（C#版本）中可以看到：

```csharp
var servicesResult = await bleDevice.GetGattServicesAsync(BluetoothCacheMode.Uncached);

// Find our WiFi Helper service
var wifiService = servicesResult.Services.FirstOrDefault(s => s.Uuid == SERVICE_UUID);
```

**关键差异：**
- C#的WinRT API返回`GattDeviceService`对象，有`.Uuid`属性
- Flutter的WinBle包**直接返回String UUID**，这是包装后的简化API
- 我们的代码错误地假设了和C# WinRT相同的对象结构

**Unpair功能：**
program.cs也有类似功能：
```csharp
var unpairResult = await pairingInfo.UnpairAsync();
```

我们通过`WindowsPairingService`暴露了相同的底层API。

---

## 影响范围

### 修改的文件
1. ✅ `lib/shared/services/winble_wifi_helper_service.dart` - 服务UUID类型修复 + unpair方法
2. ✅ `lib/shared/services/winble_service.dart` - 添加unpairDevice包装
3. ✅ `lib/features/devices/presentation/pages/wifi_provision_page.dart` - UI按钮 + 对话框

### 未修改的文件
- ❌ `windows/runner/windows_ble_pairing_plugin.cpp` - 不需要改动
- ❌ `lib/shared/services/windows_pairing_service.dart` - 已有unpairDevice方法，无需改动

---

## 下一步

现在应该可以：

1. ✅ **成功识别WiFi Helper GATT服务**
2. ✅ **读写SSID、PSK特征**
3. ✅ **发送CONNECT命令**
4. ✅ **监控WiFi连接状态**
5. ✅ **解除配对并重新输入PIN**（新功能）

### 完整的配对流程

```
用户操作                    | 应用行为                | Pi行为
---------------------------|------------------------|--------------------
1. 点击"Connect & Pair"     | 开始配对请求            | 检测配对请求
                           |                        | 
2. (如果已配对)            | 显示"已配对"            | 不生成PIN
   点击"Unpair Device"     | 调用Windows unpair API | 清除配对信息
                           |                        | 
3. 再次点击"Connect & Pair" | 开始新的配对请求        | 生成6位数PIN
                           |                        | OLED显示PIN
                           |                        | 
4. 弹出PIN输入对话框       | 等待用户输入            | 等待PIN确认
                           |                        | 
5. 输入PIN并点击"Continue" | 提交PIN到C++           | 验证PIN
                           | 等待配对完成            | 配对成功
                           |                        | 
6. "Connected & Paired"    | 连接成功               | BLE连接建立
                           | 发现GATT服务            | 广播WiFi Helper服务
                           |                        | 
7. 输入WiFi凭据            | 写入SSID/PSK特征       | 接收WiFi凭据
   点击"Provision WiFi"    | 发送CONNECT命令        | 连接WiFi
                           |                        | 
8. 监控状态                | 读取STATUS特征         | 报告连接进度
                           | Connecting → Success   | WiFi连接成功
```

---

## 总结

这两个修复解决了关键的兼容性和用户体验问题：

1. **技术问题：** WinBle API返回类型与预期不符，导致服务发现失败
2. **用户体验问题：** 没有办法清除旧配对，无法重新输入PIN

现在用户有完整的控制：
- ✅ 可以解除配对
- ✅ 可以重新配对
- ✅ 可以重新输入PIN
- ✅ Pi会重新生成PIN
- ✅ 服务发现正常工作
- ✅ WiFi配置可以正常进行

**测试一下吧！** 🚀
