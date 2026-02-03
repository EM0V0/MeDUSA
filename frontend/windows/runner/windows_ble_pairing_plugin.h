#ifndef RUNNER_WINDOWS_BLE_PAIRING_PLUGIN_H_
#define RUNNER_WINDOWS_BLE_PAIRING_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar.h>
#include <memory>
#include <string>
#include <mutex>
#include <map>

// C-style plugin registration function
// Note: No dllexport needed since this is built into the executable
#ifdef __cplusplus
extern "C" {
#endif

void WindowsBlePairingPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#ifdef __cplusplus
}  // extern "C"
#endif

namespace windows_ble_pairing {

// Windows BLE Pairing Plugin with MTA threading for stability
// Inherits from flutter::Plugin for proper lifecycle management
class WindowsBlePairingPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      FlutterDesktopPluginRegistrarRef registrar);

  WindowsBlePairingPlugin();
  virtual ~WindowsBlePairingPlugin();

  // Disallow copy and assign
  WindowsBlePairingPlugin(const WindowsBlePairingPlugin&) = delete;
  WindowsBlePairingPlugin& operator=(const WindowsBlePairingPlugin&) = delete;

 private:
  // Handle method calls from Dart
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Handle PIN input method calls from Dart
  void HandlePinMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Pair with device (runs in background MTA thread)
  void PairDevice(
      const std::string& device_address,
      bool require_authentication,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void IsDevicePaired(
      const std::string& device_address,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void UnpairDevice(
      const std::string& device_address,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Helper: Convert MAC address string to Bluetooth address (uint64_t)
  static uint64_t MacStringToBluetoothAddress(const std::string& mac_string);

  // Global pairing lock to prevent concurrent operations on the same device
  static std::mutex pairing_mutex_;
  static std::map<std::string, bool> active_operations_;

  // PIN input synchronization
  static std::mutex pin_mutex_;
  static std::condition_variable pin_cv_;
  static std::string pending_pin_;
  static bool pin_ready_;
  
  // Store method channel for PIN requests
  static flutter::MethodChannel<flutter::EncodableValue>* pin_channel_;
};

}  // namespace windows_ble_pairing

#endif  // RUNNER_WINDOWS_BLE_PAIRING_PLUGIN_H_
