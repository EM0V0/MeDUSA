# ✅ 完整的 PIN 配对实现

## 概述

现在应用程序已实现完整的 PIN 配对流程，参考了 `program.cs` 的C# WinRT实现：

1. **扫描设备** → 找到 MeDUSA-Helper
2. **显示PIN对话框** → 用户查看 Raspberry Pi OLED 屏幕
3. **输入6位PIN** → 用户在Flutter UI中输入
4. **提交到C++插件** → 通过 method channel 发送PIN
5. **C++完成配对** → 使用 `args.Accept(pin)` 验证
6. **配对成功** → 可以连接并写入WiFi凭据

## 工作流程

### Flutter UI 端

```dart
// 1. 用户点击"连接设备"
_connectAndPair()

// 2. Flutter 显示PIN输入对话框
_showPinInputDialog()

// 3. 用户输入6位PIN并点击"继续"
// 4. 立即提交PIN到C++
await _wifiService.submitPinToPlugin(pin)

// 5. 等待C++配对完成
final success = await _wifiService.connectAndPair(deviceAddress)
```

### C++ 插件端

```cpp
// 1. 接收配对请求
PairDevice(device_address, require_authentication, result)

// 2. 启动WinRT配对
custom_pairing.PairingRequested += [handler]
auto pairing_result = custom_pairing.PairAsync(...)

// 3. Windows触发PairingRequested事件
case DevicePairingKinds::ProvidePin:
    // 获取deferral允许异步等待
    auto deferral = args.GetDeferral()
    
    // 等待Flutter提交PIN (通过submitPin method channel)
    pin_cv_.wait_for(lock, std::chrono::seconds(60))
    
    // 收到PIN后提交给Windows
    args.Accept(winrt::to_hstring(pin))
    deferral.Complete()

// 4. Windows完成配对验证
// 5. 返回结果给Flutter
```

## 使用方法

### 测试配对 (3种方法)

#### 方法1: 使用环境变量快速测试

```powershell
cd d:\25fall\Capstone\ble\MeDUSA\meddevice-app-flutter-main

# 如果你知道Pi的PIN (例如从日志中看到)
$env:MEDUSA_TEST_PIN = "123456"
flutter run -d windows

# 或使用脚本
.\test_with_pin.ps1 123456
```

**优点**: 快速测试，无需每次输入  
**缺点**: 必须提前知道PIN

#### 方法2: 通过Flutter UI输入 (推荐)

```powershell
# 不设置环境变量
flutter run -d windows
```

1. 启动应用
2. 扫描设备找到 MeDUSA-Helper
3. 点击"Connect and Pair"
4. **立即显示PIN输入对话框**
5. **查看Raspberry Pi的OLED屏幕** - 应显示 "PIN: 123456"
6. 在对话框中输入相同的6位PIN
7. 点击"Continue Pairing"
8. 等待配对完成

**优点**: 真实的用户体验，符合实际使用场景  
**缺点**: 需要查看Pi的屏幕

#### 方法3: 混合模式 (开发推荐)

```powershell
# 设置默认PIN作为fallback
$env:MEDUSA_TEST_PIN = "123456"
flutter run -d windows
```

- 如果Pi使用 "123456"，自动通过
- 如果Pi使用其他PIN，可以手动输入

## 代码修改总结

### 新增/修改的文件

1. **`windows_ble_pairing_plugin.h`**
   - 添加 `pin_channel_` 静态成员

2. **`windows_ble_pairing_plugin.cpp`**
   - 初始化 `pin_channel_` 指针
   - 修改 `PairingRequested` 事件处理器:
     - 使用 `GetDeferral()` 允许异步等待
     - 等待60秒接收PIN输入
     - 收到PIN后调用 `args.Accept(pin)`
     - 完成deferral

3. **`winble_wifi_helper_service.dart`**
   - 添加 `_setupPinChannelListener()` 方法
   - 添加 `setOnPinRequested()` 回调注册
   - 现有的 `submitPinToPlugin()` 方法保持不变

4. **`wifi_provision_page.dart`**
   - 修改 `_connectAndPair()`:
     - **主动显示PIN对话框**（不等C++通知）
     - 并行启动配对过程
     - 用户输入PIN后立即提交
   - 修改 `_showPinInputDialog()`:
     - 点击"Continue"时自动调用 `submitPinToPlugin()`

### 关键设计决策

#### 为什么Flutter主动显示对话框？

**原因**: 从C++后台线程调用Flutter method channel不安全。

**解决方案**: 
1. Flutter在调用 `pairDevice` **之前**就显示PIN对话框
2. C++配对过程中遇到 `ProvidePin` 事件时，只需等待PIN输入
3. Flutter用户输入完成后，通过 `submitPin` method channel发送
4. C++收到PIN后继续配对流程

这与 `program.cs` 的同步方式不同，但更适合Flutter的异步架构。

## 参考 program.cs 的实现

### C# 版本 (同步)

```csharp
customPairing.PairingRequested += (sender, args) =>
{
    switch (args.PairingKind)
    {
        case DevicePairingKinds.ProvidePin:
            Console.Write("Enter PIN: ");
            var pin = Console.ReadLine();  // 同步等待输入
            args.Accept(pin);
            break;
    }
};
```

### C++/Flutter 版本 (异步)

```cpp
custom_pairing.PairingRequested([](sender, args) {
    case DevicePairingKinds::ProvidePin:
        auto deferral = args.GetDeferral();  // 允许异步
        
        // 等待Flutter通过method channel发送PIN
        pin_cv_.wait_for(lock, std::chrono::seconds(60));
        
        args.Accept(winrt::to_hstring(pin));
        deferral.Complete();
        break;
});
```

## 常见问题

### Q: PIN对话框没有出现？
**A**: 检查是否设置了 `MEDUSA_TEST_PIN` 环境变量。如果设置了，会自动使用该PIN，不显示对话框。

### Q: 配对失败 "Rejected by handler"?
**A**: 
1. 检查输入的PIN是否正确（区分 0 和 O，1 和 I）
2. 检查Pi的OLED屏幕显示的PIN
3. 确保在60秒内输入完成

### Q: 配对失败 "Authentication failure"?
**A**: PIN不匹配。Pi的PIN可能已经改变，刷新Pi的蓝牙或重新扫描。

### Q: 超时错误?
**A**: 
1. 确保在60秒内输入PIN并点击"Continue"
2. 检查Pi是否在附近且蓝牙开启
3. 查看Pi的日志: `journalctl -u medusa_wifi_helper -f`

## 下一步测试

1. **确保Pi正在运行** `medusa_wifi_helper` 服务
2. **Pi应显示PIN** 在OLED屏幕上
3. **运行Flutter应用**:
   ```powershell
   flutter run -d windows
   ```
4. **扫描并连接**
5. **查看Pi屏幕获取PIN**
6. **在对话框中输入PIN**
7. **配对成功后输入WiFi凭据**

## 调试日志

配对过程中会输出详细日志：

```
[WiFiProvision] Starting connection and pairing...
[WiFiProvision] Showing PIN input dialog preemptively
[WindowsPairing] PAIRING STARTED for device: 2C:CF:67:23:E8:5E
[WindowsPairing] *** PAIRING EVENT TRIGGERED ***
[WindowsPairing] PROVIDE_PIN: Need to get PIN from user
[WindowsPairing] Got deferral - can now wait for PIN input
[WindowsPairing] Waiting for PIN input from Flutter UI (60s timeout)...
[WiFiProvision] Submitting PIN to C++ plugin: 123456
[WindowsPairing] Received PIN from Flutter: 123456
[WindowsPairing] Submitting PIN to Windows...
[WindowsPairing] PIN submitted successfully
[WindowsPairing] STATUS: Paired successfully
```

## 成功！

如果一切正常，你应该看到：
- ✅ 配对成功
- ✅ 可以连接到设备
- ✅ 可以写入WiFi凭据
- ✅ 可以监控WiFi连接状态

就像 `program.cs` 的C#版本一样，但现在是在Flutter应用中！🎉
