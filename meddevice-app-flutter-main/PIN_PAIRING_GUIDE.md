# Windows BLE PIN 配对说明

## 当前状态 ✅

C++配对代码已修复：
- ✅ 使用 `GetDeferral()` 等待PIN输入
- ✅ 支持环境变量测试 (`MEDUSA_TEST_PIN`)
- ✅ 支持通过 `submitPin` method channel 接收PIN
- ✅ 60秒超时保护

## 测试方法

### 方法1: 使用环境变量快速测试（推荐用于开发）

```powershell
# 在 PowerShell 中运行：
cd d:\25fall\Capstone\ble\MeDUSA\meddevice-app-flutter-main
.\test_with_pin.ps1 123456
```

或手动设置：
```powershell
$env:MEDUSA_TEST_PIN = "123456"
flutter run -d windows
```

### 方法2: 通过Flutter UI输入PIN（需要额外开发）

目前Flutter已经有PIN输入UI (`_showPinInputDialog`)，但需要连接到C++的配对事件。

## 工作原理

1. **用户点击连接设备** → Flutter调用 `pairDevice`
2. **C++开始配对** → Windows触发 `PairingRequested` 事件
3. **事件处理器获取deferral** → 可以异步等待PIN
4. **C++等待PIN输入**：
   - 先检查 `MEDUSA_TEST_PIN` 环境变量
   - 如果没有，则等待Flutter调用 `submitPin` method channel（最多60秒）
5. **收到PIN后** → 调用 `args.Accept(pin)` 提交给Windows
6. **完成deferral** → Windows完成配对

## 查看日志

运行时查看详细配对日志：
```
[WindowsPairing] *** PAIRING EVENT TRIGGERED ***
[WindowsPairing] Got deferral - can now wait for PIN input
[WindowsPairing] Waiting for PIN input from Flutter UI...
```

## 已知问题

- **状态码17 "Rejected by handler"**: 使用了空PIN或错误的PIN
- **状态码19**: 未知错误，通常是第二次配对尝试失败
- **超时**: 如果60秒内没有输入PIN，配对会失败

## 下一步 TODO

要让Flutter UI自动弹出PIN对话框，需要：

1. **添加 Event Channel** 让C++通知Flutter显示PIN对话框
2. **修改 `PairingManager`** 或 `WinBleWiFiHelperService` 监听事件
3. **自动调用 `_showPinInputDialog()`**
4. **用户输入PIN后调用 `submitPin`** method channel

当前可以先使用环境变量方式进行测试！
