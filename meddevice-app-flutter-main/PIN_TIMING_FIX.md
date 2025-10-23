# 🕐 PIN生成时序修复

## 问题描述

用户报告：**Pi上生成PIN不是很及时**

## 根本原因分析

### 原来的错误时序

```
时间轴 | Windows应用                    | Raspberry Pi
------|-------------------------------|---------------------------
  0s  | 用户点击"Connect & Pair"       |
  0s  | ❌ 立即显示PIN输入对话框        |
  0s  | 用户看到对话框，但Pi还没生成PIN  |
  1s  | 调用 connectAndPair()          |
  2s  | C++: 调用 PairAsync()          |
  3s  | Windows BLE: 发送配对请求       | ← 配对请求到达
  3s  |                               | 🔐 生成6位数PIN
  3s  |                               | 📺 在OLED上显示PIN
  3s  | ⏳ 等待用户输入PIN...          | ⏳ 等待Windows输入PIN...
      |                               |
问题：用户已经看到PIN对话框3秒了，但Pi的OLED还没显示PIN！
```

**核心问题：**
- Flutter在配对**之前**就显示了PIN对话框
- Pi只有在收到Windows的配对请求**之后**才生成PIN
- 用户面对空的PIN对话框，不知道要等什么

---

### 修复后的正确时序

```
时间轴 | Windows应用                    | Raspberry Pi
------|-------------------------------|---------------------------
  0s  | 用户点击"Connect & Pair"       |
  0s  | 调用 connectAndPair()          |
  0s  | 显示状态："Initiating pairing..."
  1s  | C++: 调用 PairAsync()          |
  1s  | Windows BLE: 发送配对请求       | ← 配对请求到达
  1s  |                               | 🔐 立即生成6位数PIN
  1s  |                               | 📺 在OLED上显示PIN
  1s  | ← C++: PairingRequested事件触发 |
  1s  | C++: 检测到ProvidePin模式      |
  1s  | C++: 调用GetDeferral()        |
  1s  | C++: 🔔 InvokeMethod("onPinRequest") | 
  1s  | Flutter: 收到onPinRequest      |
  1s  | ✅ 显示PIN输入对话框            |
  1s  | 用户看到Pi的OLED已显示PIN       |
  1s  | 用户从OLED读取PIN并输入         |
  5s  | 用户点击"Continue Pairing"     |
  5s  | 提交PIN到C++                  |
  5s  | C++: args.Accept(pin)         | ← 验证PIN
  6s  | ✅ 配对成功                    | ✅ 配对成功
```

**优点：**
- ✅ Pi先生成PIN
- ✅ 再显示Flutter对话框
- ✅ 用户看到对话框时，PIN已经在OLED上了
- ✅ 时序同步，体验流畅

---

## 代码修改

### 1. C++端：在等待PIN时通知Flutter

**文件：** `windows/runner/windows_ble_pairing_plugin.cpp`

```cpp
case DevicePairingKinds::ProvidePin: {
  // Get a deferral to allow async PIN input
  auto deferral = args.GetDeferral();
  
  // Reset PIN state
  {
    std::lock_guard<std::mutex> lock(WindowsBlePairingPlugin::pin_mutex_);
    WindowsBlePairingPlugin::pending_pin_.clear();
    WindowsBlePairingPlugin::pin_ready_ = false;
  }
  
  // *** NEW: Notify Flutter to show PIN dialog ***
  std::cerr << "[WindowsPairing] Pi should now be generating PIN on OLED..." << std::endl;
  std::cerr << "[WindowsPairing] Notifying Flutter to show PIN input dialog" << std::endl;
  if (WindowsBlePairingPlugin::pin_channel_) {
    flutter::EncodableMap args_map;
    args_map[flutter::EncodableValue("event")] = flutter::EncodableValue("requestPin");
    args_map[flutter::EncodableValue("message")] = flutter::EncodableValue("Enter PIN from Raspberry Pi OLED");
    
    WindowsBlePairingPlugin::pin_channel_->InvokeMethod(
      "onPinRequest",  // 调用Flutter的method handler
      std::make_unique<flutter::EncodableValue>(args_map)
    );
    std::cerr << "[WindowsPairing] PIN request notification sent to Flutter" << std::endl;
  } else {
    std::cerr << "[WindowsPairing] WARNING: pin_channel_ is null" << std::endl;
  }
  
  // Wait for Flutter to provide PIN (60 seconds timeout)
  std::cerr << "[WindowsPairing] Waiting for PIN from Flutter UI..." << std::endl;
  // ... 等待逻辑 ...
}
```

**关键点：**
- 使用 `InvokeMethod("onPinRequest")` 从C++调用Flutter
- 在Pi生成PIN的**同一时刻**通知Flutter
- 利用已经存在的 `pin_channel_`

---

### 2. Flutter Service：处理onPinRequest回调

**文件：** `lib/shared/services/winble_wifi_helper_service.dart`

```dart
// PIN request callback - set by UI (no BuildContext needed, UI will handle it)
Function()? _onPinRequested;

/// Register callback for PIN requests from C++
/// The callback should show the PIN input dialog
void setOnPinRequested(Function() callback) {
  _onPinRequested = callback;
  debugPrint('[WinBleWiFi] 🔐 PIN request callback registered');
}

/// Setup method channel listener for PIN requests from C++
void _setupPinChannelListener() {
  _pinChannel.setMethodCallHandler((call) async {
    debugPrint('[WinBleWiFi] 📥 Received method call from C++: ${call.method}');
    
    switch (call.method) {
      case 'onPinRequest':
        debugPrint('[WinBleWiFi] 🔐 C++ requesting PIN input (Pi has generated PIN on OLED)');
        // Notify UI to show PIN dialog
        if (_onPinRequested != null) {
          debugPrint('[WinBleWiFi] 🔐 Invoking PIN request callback');
          _onPinRequested!();  // 调用UI的回调
        } else {
          debugPrint('[WinBleWiFi] ⚠️ No PIN request callback registered!');
        }
        return null;
        
      default:
        debugPrint('[WinBleWiFi] ❌ Unknown method: ${call.method}');
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  });
  
  debugPrint('[WinBleWiFi] 📡 PIN channel listener setup complete');
}
```

**关键点：**
- 监听 `onPinRequest` 方法调用
- 调用UI注册的回调（不需要BuildContext）
- UI层负责显示对话框

---

### 3. Flutter UI：注册回调并简化配对流程

**文件：** `lib/features/devices/presentation/pages/wifi_provision_page.dart`

**修改前（错误）：**
```dart
Future<void> _connectAndPair() async {
  // ❌ 错误：提前显示PIN对话框
  debugPrint('[WiFiProvision] Showing PIN input dialog preemptively');
  final pinFuture = _showPinInputDialog();
  
  // 然后才开始配对
  final pairingFuture = _wifiService.connectAndPair(_deviceAddress);
  
  // 等待PIN输入...
  final pin = await pinFuture;
  // ...
}
```

**修改后（正确）：**
```dart
/// Setup the PIN request callback
/// This will be called when C++ plugin requests PIN input
void _setupPairingCallback() {
  debugPrint('[WiFiProvision] Setting up PIN request callback');
  _wifiService.setOnPinRequested(() {
    debugPrint('[WiFiProvision] 🔐 PIN requested by C++ - Pi has generated PIN on OLED');
    debugPrint('[WiFiProvision] 📱 Showing PIN input dialog NOW');
    _showPinInputDialog();  // 此时才显示对话框
  });
}

Future<void> _connectAndPair() async {
  setState(() {
    _isConnecting = true;
    _statusMessage = 'Connecting to device...';
  });

  try {
    debugPrint('[WiFiProvision] Starting connection and pairing...');
    debugPrint('[WiFiProvision] Device address: $_deviceAddress');
    
    setState(() {
      _statusMessage = 'Initiating pairing...\nPIN dialog will appear when Pi generates PIN.';
    });
    
    // ✅ 正确：直接开始配对
    // PIN对话框会在C++通知时自动显示
    final success = await _wifiService.connectAndPair(_deviceAddress);
    
    // 配对完成后的处理...
  }
}
```

**关键点：**
- 在 `initState()` 中注册 `_setupPairingCallback()`
- 回调直接调用 `_showPinInputDialog()`
- `_connectAndPair()` 只负责启动配对，不管PIN对话框

---

## 完整的事件流

### 配对时序图

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Flutter UI │         │  Dart Code  │         │  C++ Plugin │         │     Pi      │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │                       │
       │ 1. 点击按钮            │                       │                       │
       │──────────────────────>│                       │                       │
       │                       │                       │                       │
       │                       │ 2. connectAndPair()   │                       │
       │                       │──────────────────────>│                       │
       │                       │                       │                       │
       │                       │                       │ 3. PairAsync()        │
       │                       │                       │──────────────────────>│
       │                       │                       │                       │
       │                       │                       │                       │ 4. 生成PIN
       │                       │                       │                       │───┐
       │                       │                       │                       │   │
       │                       │                       │                       │<──┘
       │                       │                       │                       │
       │                       │                       │                       │ 5. 显示PIN
       │                       │                       │                       │───┐
       │                       │                       │                       │   │ OLED
       │                       │                       │                       │<──┘
       │                       │                       │                       │
       │                       │                       │ 6. PairingRequested   │
       │                       │                       │   Event               │
       │                       │                       │<──────────────────────│
       │                       │                       │                       │
       │                       │                       │ 7. GetDeferral()      │
       │                       │                       │───┐                   │
       │                       │                       │   │                   │
       │                       │                       │<──┘                   │
       │                       │                       │                       │
       │                       │ 8. onPinRequest       │                       │
       │                       │   InvokeMethod()      │                       │
       │                       │<──────────────────────│                       │
       │                       │                       │                       │
       │                       │ 9. 调用回调            │                       │
       │                       │───┐                   │                       │
       │                       │   │                   │                       │
       │                       │<──┘                   │                       │
       │                       │                       │                       │
       │ 10. 显示PIN对话框      │                       │                       │
       │<──────────────────────│                       │                       │
       │                       │                       │                       │
       │ 11. 用户输入PIN        │                       │                       │
       │───┐                   │                       │                       │
       │   │ 从OLED读取          │                       │                       │
       │<──┘                   │                       │                       │
       │                       │                       │                       │
       │ 12. 点击Continue       │                       │                       │
       │──────────────────────>│                       │                       │
       │                       │                       │                       │
       │                       │ 13. submitPin()       │                       │
       │                       │──────────────────────>│                       │
       │                       │                       │                       │
       │                       │                       │ 14. pin_cv_.notify_one()
       │                       │                       │───┐                   │
       │                       │                       │   │                   │
       │                       │                       │<──┘                   │
       │                       │                       │                       │
       │                       │                       │ 15. args.Accept(pin)  │
       │                       │                       │──────────────────────>│
       │                       │                       │                       │
       │                       │                       │                       │ 16. 验证PIN
       │                       │                       │                       │───┐
       │                       │                       │                       │   │
       │                       │                       │                       │<──┘
       │                       │                       │                       │
       │                       │                       │ 17. ✅ Paired         │
       │                       │                       │<──────────────────────│
       │                       │                       │                       │
       │                       │ 18. ✅ Success        │                       │
       │                       │<──────────────────────│                       │
       │                       │                       │                       │
       │ 19. 关闭对话框         │                       │                       │
       │<──────────────────────│                       │                       │
       │                       │                       │                       │
```

---

## 测试结果预期

### 修复前的体验（差）

1. 用户点击"Connect & Pair"
2. **立即看到PIN输入对话框**
3. 用户看向Pi的OLED屏幕 → **什么都没有** ❌
4. 等待3-5秒...
5. Pi的OLED终于显示PIN
6. 用户输入PIN

**问题：** 用户不知道为什么要等，体验混乱

---

### 修复后的体验（好）

1. 用户点击"Connect & Pair"
2. 看到状态："Initiating pairing... PIN dialog will appear when Pi generates PIN."
3. 等待1-2秒（BLE配对请求发送）
4. **Pi的OLED显示PIN** ✅
5. **同时Flutter显示PIN输入对话框** ✅
6. 用户看到对话框时，OLED上已经有PIN了
7. 立即输入PIN，无需等待

**优点：** 时序同步，用户体验流畅

---

## 技术细节

### Method Channel 双向通信

```
Flutter (Dart)  <──────── InvokeMethod ────────  C++ Plugin
                          "onPinRequest"
                
Flutter (Dart)  ────────> InvokeMethod ──────>  C++ Plugin
                          "submitPin"
                          { pin: "123456" }
```

**关键API：**
- C++ → Dart: `pin_channel_->InvokeMethod("onPinRequest", ...)`
- Dart → C++: `_pinChannel.invokeMethod("submitPin", {'pin': pin})`
- Dart监听: `_pinChannel.setMethodCallHandler((call) => ...)`

---

### 条件变量同步

C++使用`std::condition_variable`等待Dart提交PIN：

```cpp
// 重置状态
{
  std::lock_guard<std::mutex> lock(pin_mutex_);
  pending_pin_.clear();
  pin_ready_ = false;
}

// 通知Flutter显示对话框
pin_channel_->InvokeMethod("onPinRequest", ...);

// 等待PIN（60秒超时）
{
  std::unique_lock<std::mutex> lock(pin_mutex_);
  if (pin_cv_.wait_for(lock, std::chrono::seconds(60),
      [] { return pin_ready_; })) {
    pin_to_use = pending_pin_;  // 成功获取PIN
  } else {
    // 超时 - 配对失败
  }
}
```

**Dart提交PIN时：**
```dart
await _pinChannel.invokeMethod('submitPin', {'pin': pin});
```

**C++收到PIN：**
```cpp
{
  std::lock_guard<std::mutex> lock(pin_mutex_);
  pending_pin_ = *pin_str;
  pin_ready_ = true;
}
pin_cv_.notify_one();  // 唤醒等待线程
```

---

## 总结

**修复的本质：**
- ❌ **修复前**：Flutter主动显示对话框，Pi被动生成PIN → 时序错乱
- ✅ **修复后**：Pi主动生成PIN，Flutter被动显示对话框 → 时序同步

**关键改进：**
1. C++在收到配对请求时立即通知Flutter
2. Flutter收到通知时才显示PIN对话框
3. 此时Pi的OLED已经显示了PIN
4. 用户体验流畅，无需等待或困惑

**代码更改：**
- C++：添加 `InvokeMethod("onPinRequest")`
- Dart Service：处理 `onPinRequest` 回调
- Dart UI：注册回调，移除提前显示对话框的逻辑

现在PIN生成和对话框显示**完美同步**！🎉
