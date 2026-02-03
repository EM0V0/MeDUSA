#include "windows_ble_pairing_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <windows.h>
#include <winrt/base.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>

#include <chrono>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <map>
#include <algorithm>

namespace windows_ble_pairing {

using namespace winrt;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Enumeration;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Foundation::Collections;

// Initialize static members
std::mutex WindowsBlePairingPlugin::pairing_mutex_;
std::map<std::string, bool> WindowsBlePairingPlugin::active_operations_;
std::mutex WindowsBlePairingPlugin::pin_mutex_;
std::condition_variable WindowsBlePairingPlugin::pin_cv_;
std::string WindowsBlePairingPlugin::pending_pin_;
bool WindowsBlePairingPlugin::pin_ready_ = false;
flutter::MethodChannel<flutter::EncodableValue>* WindowsBlePairingPlugin::pin_channel_ = nullptr;

// Helper function to convert wide string to UTF-8 using Windows API
static std::string WideStringToUtf8(const std::wstring& wide_string) {
  if (wide_string.empty()) return "";
  
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide_string.c_str(), 
                                        (int)wide_string.length(), nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide_string.c_str(), 
                      (int)wide_string.length(), &result[0], size_needed, nullptr, nullptr);
  return result;
}

// Overload to convert winrt::hstring to UTF-8
static std::string WideStringToUtf8(const winrt::hstring& hstr) {
  return WideStringToUtf8(std::wstring(hstr.c_str()));
}

// Convert MAC address string (e.g., "AA:BB:CC:DD:EE:FF") to uint64_t
uint64_t WindowsBlePairingPlugin::MacStringToBluetoothAddress(const std::string& mac_string) {
  std::string clean_address = mac_string;
  // Remove colons and dashes
  clean_address.erase(std::remove(clean_address.begin(), clean_address.end(), ':'), clean_address.end());
  clean_address.erase(std::remove(clean_address.begin(), clean_address.end(), '-'), clean_address.end());
  
  // Convert hex string to uint64_t
  return std::stoull(clean_address, nullptr, 16);
}

// Register the plugin - called once at application startup
void WindowsBlePairingPlugin::RegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar_ref) {
  
  // Use PluginRegistrarManager to get a properly initialized registrar
  auto* registrar =
      flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref);
  
  // Create plugin instance and transfer ownership to registrar
  auto plugin = std::make_unique<WindowsBlePairingPlugin>();
  auto* plugin_ptr = plugin.get();
  
  // Create method channel using registrar's messenger
  // Channel name must match the Dart side: com.medusa/windows_ble_pairing
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(),
      "com.medusa/windows_ble_pairing",
      &flutter::StandardMethodCodec::GetInstance());

  // Set method call handler
  channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  // Create PIN input method channel
  auto pin_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(),
      "com.medusa/windows_ble_pairing/pin",
      &flutter::StandardMethodCodec::GetInstance());

  // Set PIN method call handler
  pin_channel->SetMethodCallHandler(
      [plugin_ptr](const auto& call, auto result) {
        plugin_ptr->HandlePinMethodCall(call, std::move(result));
      });
      
  // Keep channels alive using static storage
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_keeper = std::move(channel);
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> pin_channel_keeper = std::move(pin_channel);
  
  // Store pin_channel pointer for PIN request notifications
  WindowsBlePairingPlugin::pin_channel_ = pin_channel_keeper.get();
  
  // Transfer plugin ownership to registrar to ensure it lives as long as the engine
  registrar->AddPlugin(std::move(plugin));
}

// C-style registration function for Flutter
// Must use extern "C" to prevent name mangling for C++ linkage
extern "C" {
void WindowsBlePairingPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  WindowsBlePairingPlugin::RegisterWithRegistrar(registrar);
}
}  // extern "C"

WindowsBlePairingPlugin::WindowsBlePairingPlugin() {}

WindowsBlePairingPlugin::~WindowsBlePairingPlugin() {}

void WindowsBlePairingPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name() == "pairDevice") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }

    auto device_address_it = arguments->find(flutter::EncodableValue("deviceAddress"));
    auto require_auth_it = arguments->find(flutter::EncodableValue("requireAuthentication"));

    if (device_address_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "deviceAddress is required");
      return;
    }

    std::string device_address = std::get<std::string>(device_address_it->second);
    bool require_authentication = true;
    if (require_auth_it != arguments->end()) {
      require_authentication = std::get<bool>(require_auth_it->second);
    }

    PairDevice(device_address, require_authentication, std::move(result));
  }
  else if (method_call.method_name() == "isDevicePaired") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }

    auto device_address_it = arguments->find(flutter::EncodableValue("deviceAddress"));
    if (device_address_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "deviceAddress is required");
      return;
    }

    std::string device_address = std::get<std::string>(device_address_it->second);
    IsDevicePaired(device_address, std::move(result));
  }
  else if (method_call.method_name() == "unpairDevice") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
      return;
    }

    auto device_address_it = arguments->find(flutter::EncodableValue("deviceAddress"));
    if (device_address_it == arguments->end()) {
      result->Error("MISSING_ARGUMENT", "deviceAddress is required");
      return;
    }

    std::string device_address = std::get<std::string>(device_address_it->second);
    UnpairDevice(device_address, std::move(result));
  }
  else {
    result->NotImplemented();
  }
}

void WindowsBlePairingPlugin::HandlePinMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const auto& method_name = method_call.method_name();
  
  if (method_name == "submitPin") {
    // Get PIN from Dart
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto pin_it = arguments->find(flutter::EncodableValue("pin"));
      if (pin_it != arguments->end()) {
        const auto* pin_str = std::get_if<std::string>(&pin_it->second);
        if (pin_str) {
          std::cerr << "[WindowsPairing] Received PIN from Flutter (length: " << pin_str->length() << " chars)" << std::endl;
          
          // Set PIN and notify waiting thread
          {
            std::lock_guard<std::mutex> lock(pin_mutex_);
            pending_pin_ = *pin_str;
            pin_ready_ = true;
          }
          pin_cv_.notify_one();
          
          result->Success(flutter::EncodableValue(true));
          return;
        }
      }
    }
    result->Error("INVALID_ARGUMENT", "PIN not provided");
  } else {
    result->NotImplemented();
  }
}

void WindowsBlePairingPlugin::PairDevice(
    const std::string& device_address,
    bool require_authentication,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Check if operation is already in progress for this device
  {
    std::lock_guard<std::mutex> lock(pairing_mutex_);
    if (active_operations_[device_address]) {
      result->Error("OPERATION_IN_PROGRESS", 
                   "A pairing operation is already in progress for this device");
      return;
    }
    // Mark operation as active
    active_operations_[device_address] = true;
  }
  
  // Execute pairing on background MTA thread
  // CRITICAL: WinRT DevicePairingRequestedEventArgs asserts !is_sta_thread()
  // This means WinRT Bluetooth APIs MUST run in MTA, not STA!
  // Running in MTA also prevents blocking the Flutter UI thread
  std::thread([device_address, require_authentication, 
               result = std::move(result)]() mutable {
    // RAII guard to ensure operation flag is cleared
    struct OperationGuard {
      std::string address;
      ~OperationGuard() {
        std::lock_guard<std::mutex> lock(WindowsBlePairingPlugin::pairing_mutex_);
        WindowsBlePairingPlugin::active_operations_[address] = false;
      }
    } guard{device_address};
    
    try {
      std::cerr << "\n========================================" << std::endl;
      std::cerr << "[WindowsPairing] PAIRING STARTED for device: " << device_address << std::endl;
      std::cerr << "[WindowsPairing] Require authentication: " << (require_authentication ? "YES" : "NO") << std::endl;
      std::cerr << "========================================\n" << std::endl;
      
      // Initialize COM as MTA (Multi-Threaded Apartment)
      // This is REQUIRED - WinRT Bluetooth asserts !is_sta_thread() in debug builds
      std::cerr << "[WindowsPairing] Step 1: Initializing COM apartment (MTA)..." << std::endl;
      init_apartment(apartment_type::multi_threaded);
      std::cerr << "[WindowsPairing] Step 1: COM initialized successfully" << std::endl;

      // Convert MAC address string to uint64_t
      std::cerr << "[WindowsPairing] Step 2: Converting MAC address to uint64..." << std::endl;
      uint64_t bluetooth_address = WindowsBlePairingPlugin::MacStringToBluetoothAddress(device_address);
      if (bluetooth_address == 0) {
        std::cerr << "[WindowsPairing] ERROR: Invalid MAC address format" << std::endl;
        result->Error("INVALID_ADDRESS", "Invalid Bluetooth address format");
        uninit_apartment();
        return;
      }
      std::cerr << "[WindowsPairing] Step 2: Address converted = 0x" << std::hex << bluetooth_address << std::dec << std::endl;

      // Get BLE device from address (async operation)
      std::cerr << "[WindowsPairing] Step 3: Getting BLE device from address..." << std::endl;
      auto ble_device_async = BluetoothLEDevice::FromBluetoothAddressAsync(bluetooth_address);
      std::cerr << "[WindowsPairing] Step 3: Waiting for device object..." << std::endl;
      auto ble_device = ble_device_async.get();

      if (!ble_device) {
        std::cerr << "[WindowsPairing] ERROR: Device not found" << std::endl;
        result->Error("DEVICE_NOT_FOUND", "Could not create device object from address");
        uninit_apartment();
        return;
      }
      std::cerr << "[WindowsPairing] Step 3: Device object created successfully" << std::endl;

      // Get device information for pairing
      std::cerr << "[WindowsPairing] Step 4: Getting device pairing information..." << std::endl;
      auto device_info = ble_device.DeviceInformation();
      auto pairing_info = device_info.Pairing();
      std::cerr << "[WindowsPairing] Step 4: Pairing info retrieved" << std::endl;

      // Check if already paired
      std::cerr << "[WindowsPairing] Step 5: Checking current pairing status..." << std::endl;
      bool is_paired = pairing_info.IsPaired();
      std::cerr << "[WindowsPairing] Step 5: Device is " << (is_paired ? "ALREADY PAIRED" : "NOT PAIRED") << std::endl;
      
      // ALWAYS try to unpair first to clear any stuck state
      // This is critical because Windows might have a stuck pairing operation
      std::cerr << "[WindowsPairing] Step 5a: Forcing unpair to clear any stuck state..." << std::endl;
      try {
        auto unpair_result = pairing_info.UnpairAsync().get();
        auto unpair_status = unpair_result.Status();
        std::cerr << "[WindowsPairing] Step 5a: Unpair result = " << (int)unpair_status << std::endl;
        
        if (unpair_status == DeviceUnpairingResultStatus::Unpaired) {
          std::cerr << "[WindowsPairing] Step 5a: Unpaired successfully - stuck state cleared!" << std::endl;
        } else if (unpair_status == DeviceUnpairingResultStatus::AlreadyUnpaired) {
          std::cerr << "[WindowsPairing] Step 5a: Device was already unpaired" << std::endl;
        } else {
          std::cerr << "[WindowsPairing] Step 5a: Unpair returned: " << (int)unpair_status << std::endl;
        }
        
        // Wait longer for Windows to fully process the unpair
        // Status code 19 suggests the previous operation hasn't fully cleared
        std::cerr << "[WindowsPairing] Step 5b: Waiting 5 seconds for Windows to fully clear pairing state..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(5));
        std::cerr << "[WindowsPairing] Step 5b: Wait complete, proceeding to pair" << std::endl;
        
      } catch (const hresult_error& ex) {
        std::cerr << "[WindowsPairing] Step 5a: Unpair threw exception (expected if not paired): " 
                  << WideStringToUtf8(ex.message()) << std::endl;
        std::cerr << "[WindowsPairing] Step 5a: Continuing to pairing anyway..." << std::endl;
      } catch (...) {
        std::cerr << "[WindowsPairing] Step 5a: Unpair threw unknown exception, continuing..." << std::endl;
      }

      // ========================================================================
      // CUSTOM PAIRING - Triggers Windows native PIN dialog
      // Following the successful approach from program.cs
      // ========================================================================
      
      std::cerr << "\n[WindowsPairing] ========== CUSTOM PAIRING SETUP ==========" << std::endl;
      
      // Get CustomPairing object (required for PIN-based pairing)
      std::cerr << "[WindowsPairing] Step 6: Getting CustomPairing object..." << std::endl;
      auto custom_pairing = pairing_info.Custom();
      std::cerr << "[WindowsPairing] Step 6: CustomPairing object obtained" << std::endl;
      
      // Define which pairing methods we support
      std::cerr << "[WindowsPairing] Step 7: Configuring pairing kinds..." << std::endl;
      std::cerr << "[WindowsPairing]   - ProvidePin: User enters PIN (PRIMARY MODE)" << std::endl;
      std::cerr << "[WindowsPairing]   - ConfirmPinMatch: User confirms PIN match" << std::endl;
      std::cerr << "[WindowsPairing]   - DisplayPin: System displays PIN to user" << std::endl;
      std::cerr << "[WindowsPairing]   - ConfirmOnly: Just Works mode (fallback)" << std::endl;
      
      auto pairing_kinds = 
          DevicePairingKinds::ProvidePin |
          DevicePairingKinds::ConfirmPinMatch |
          DevicePairingKinds::DisplayPin |
          DevicePairingKinds::ConfirmOnly;

      std::cerr << "[WindowsPairing] Step 7: Pairing kinds configured" << std::endl;
      
      // Set protection level
      std::cerr << "[WindowsPairing] Step 8: Setting protection level..." << std::endl;
      auto protection_level = require_authentication
          ? DevicePairingProtectionLevel::EncryptionAndAuthentication
          : DevicePairingProtectionLevel::Encryption;
      std::cerr << "[WindowsPairing] Step 8: Protection level = " 
                << (require_authentication ? "EncryptionAndAuthentication" : "Encryption") << std::endl;
      
      // CRITICAL: Must register PairingRequested handler for CustomPairing to work
      // But we need to let Windows show its native PIN dialog, not auto-accept
      std::cerr << "[WindowsPairing] DEBUG: Registering PairingRequested handler..." << std::endl;
      std::cerr << "[WindowsPairing] DEBUG: Handler will let Windows show native PIN dialog" << std::endl;
      
      winrt::event_token pairing_token = custom_pairing.PairingRequested(
        [](DeviceInformationCustomPairing sender, DevicePairingRequestedEventArgs args) {
          auto pairing_kind = args.PairingKind();
          
          std::cerr << "[WindowsPairing] *** PAIRING EVENT TRIGGERED ***" << std::endl;
          std::cerr << "[WindowsPairing] Pairing kind: " << (int)pairing_kind << std::endl;
          
          switch (pairing_kind) {
            case DevicePairingKinds::ProvidePin: {
              std::cerr << "[WindowsPairing] PROVIDE_PIN: Need to get PIN from user" << std::endl;
              std::cerr << "[WindowsPairing] CRITICAL: Must call args.Accept() with PIN" << std::endl;
              
              // Get a deferral to allow async PIN input
              auto deferral = args.GetDeferral();
              std::cerr << "[WindowsPairing] Got deferral - can now wait for PIN input" << std::endl;
              
              // Reset PIN state
              {
                std::lock_guard<std::mutex> lock(WindowsBlePairingPlugin::pin_mutex_);
                WindowsBlePairingPlugin::pending_pin_.clear();
                WindowsBlePairingPlugin::pin_ready_ = false;
              }
              
              // CRITICAL: Notify Flutter to show PIN input dialog
              std::cerr << "[WindowsPairing] >>> Notifying Flutter to show PIN dialog..." << std::endl;
              if (WindowsBlePairingPlugin::pin_channel_) {
                std::cerr << "[WindowsPairing] >>> Calling pin_channel_->InvokeMethod(\"onPinRequest\")..." << std::endl;
                WindowsBlePairingPlugin::pin_channel_->InvokeMethod(
                  "onPinRequest",
                  std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{})
                );
                std::cerr << "[WindowsPairing] >>> PIN request sent to Flutter successfully" << std::endl;
              } else {
                std::cerr << "[WindowsPairing] ERROR: pin_channel_ is nullptr!" << std::endl;
              }
              
              std::string pin_to_use;
              
              // Wait for Flutter to provide PIN (60 seconds timeout)
              std::cerr << "[WindowsPairing] Waiting for PIN from Flutter UI..." << std::endl;
              std::cerr << "[WindowsPairing] User should enter PIN from Raspberry Pi OLED screen" << std::endl;
              
              {
                std::unique_lock<std::mutex> lock(WindowsBlePairingPlugin::pin_mutex_);
                if (WindowsBlePairingPlugin::pin_cv_.wait_for(lock, std::chrono::seconds(60),
                    [] { return WindowsBlePairingPlugin::pin_ready_; })) {
                  pin_to_use = WindowsBlePairingPlugin::pending_pin_;
                  std::cerr << "[WindowsPairing] SUCCESS: Received PIN from Flutter (length: " << pin_to_use.length() << " chars)" << std::endl;
                } else {
                  // Timeout - no fallback, just fail
                  std::cerr << "[WindowsPairing] ERROR: Timeout waiting for PIN input (60 seconds)" << std::endl;
                  std::cerr << "[WindowsPairing] User did not enter PIN in time" << std::endl;
                  std::cerr << "[WindowsPairing] Rejecting pairing" << std::endl;
                  deferral.Complete();
                  return;
                }
              }
              
              // Submit the PIN
              if (!pin_to_use.empty()) {
                std::cerr << "[WindowsPairing] Submitting PIN to Windows BLE stack..." << std::endl;
                args.Accept(winrt::to_hstring(pin_to_use));
                std::cerr << "[WindowsPairing] PIN accepted, waiting for Windows to verify..." << std::endl;
              } else {
                std::cerr << "[WindowsPairing] ERROR: PIN is empty, rejecting pairing" << std::endl;
              }
              
              // Complete the deferral
              deferral.Complete();
              std::cerr << "[WindowsPairing] Deferral completed" << std::endl;
              break;
            }
            case DevicePairingKinds::ConfirmPinMatch:
              std::cerr << "[WindowsPairing] CONFIRM_PIN_MATCH: PIN = " << WideStringToUtf8(args.Pin()) << std::endl;
              std::cerr << "[WindowsPairing] Auto-accepting PIN match confirmation" << std::endl;
              args.Accept();
              break;
            case DevicePairingKinds::DisplayPin:
              std::cerr << "[WindowsPairing] DISPLAY_PIN: PIN = " << WideStringToUtf8(args.Pin()) << std::endl;
              std::cerr << "[WindowsPairing] Auto-accepting PIN display" << std::endl;
              args.Accept();
              break;
            case DevicePairingKinds::ConfirmOnly:
              std::cerr << "[WindowsPairing] CONFIRM_ONLY: Just Works mode" << std::endl;
              std::cerr << "[WindowsPairing] Auto-accepting Just Works" << std::endl;
              args.Accept();
              break;
            default:
              std::cerr << "[WindowsPairing] UNKNOWN pairing kind: " << (int)pairing_kind << std::endl;
              std::cerr << "[WindowsPairing] Auto-accepting unknown type" << std::endl;
              args.Accept();
              break;
          }
          
          std::cerr << "[WindowsPairing] Event handler completed" << std::endl;
        }
      );
      
      std::cerr << "[WindowsPairing] DEBUG: Event handler registered successfully" << std::endl;
      
      // Initiate custom pairing
      std::cerr << "[WindowsPairing] DEBUG: About to call PairAsync()..." << std::endl;
      std::cerr << "[WindowsPairing] DEBUG: Pairing kinds = 0x" << std::hex << (int)pairing_kinds << std::dec << std::endl;
      std::cerr << "[WindowsPairing] DEBUG: Protection level = " << (int)protection_level << std::endl;
      
      auto pairing_result_async = custom_pairing.PairAsync(pairing_kinds, protection_level);
      
      std::cerr << "[WindowsPairing] DEBUG: PairAsync() called, returned IAsyncOperation" << std::endl;
      std::cerr << "[WindowsPairing] DEBUG: Now calling .get() to wait for result..." << std::endl;
      std::cerr << "[WindowsPairing] DEBUG: (This will block if waiting for user input)" << std::endl;
      
      auto pairing_result = pairing_result_async.get();
      
      std::cerr << "[WindowsPairing] DEBUG: .get() returned! Pairing operation completed" << std::endl;

      // Unregister event handler
      std::cerr << "[WindowsPairing] DEBUG: Unregistering event handler..." << std::endl;
      custom_pairing.PairingRequested(pairing_token);

      // Check result and provide detailed status
      std::cerr << "\n[WindowsPairing] ========== PROCESSING RESULT ==========" << std::endl;
      auto status = pairing_result.Status();
      std::cerr << "[WindowsPairing] Pairing result status code = " << (int)status << std::endl;
      
      bool success = (status == DevicePairingResultStatus::Paired ||
                     status == DevicePairingResultStatus::AlreadyPaired);
      std::cerr << "[WindowsPairing] Success = " << (success ? "TRUE" : "FALSE") << std::endl;

      // Log detailed pairing result for debugging
      std::string status_message;
      std::cerr << "[WindowsPairing] Analyzing status code..." << std::endl;
      
      switch (status) {
        case DevicePairingResultStatus::Paired:
          status_message = "Paired successfully";
          std::cerr << "[WindowsPairing] STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::AlreadyPaired:
          status_message = "Already paired";
          std::cerr << "[WindowsPairing] STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::NotReadyToPair:
          status_message = "Device not ready to pair";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::NotPaired:
          status_message = "Pairing rejected or failed";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::AuthenticationTimeout:
          status_message = "Authentication timeout";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << " (User didn't enter PIN in time?)" << std::endl;
          break;
        case DevicePairingResultStatus::AuthenticationNotAllowed:
          status_message = "Authentication not allowed";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::AuthenticationFailure:
          status_message = "Authentication failure - incorrect PIN?";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::NoSupportedProfiles:
          status_message = "No supported profiles";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::ProtectionLevelCouldNotBeMet:
          status_message = "Protection level could not be met";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::AccessDenied:
          status_message = "Access denied";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::InvalidCeremonyData:
          status_message = "Invalid ceremony data - PIN required but not provided";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          std::cerr << "[WindowsPairing] This usually means we accepted with empty/wrong PIN" << std::endl;
          break;
        case DevicePairingResultStatus::PairingCanceled:
          status_message = "Pairing canceled by user";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::OperationAlreadyInProgress:
          status_message = "Operation already in progress";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          std::cerr << "[WindowsPairing] *** CRITICAL: Previous pairing operation is still running! ***" << std::endl;
          std::cerr << "[WindowsPairing] This suggests PairAsync() was called but never completed" << std::endl;
          break;
        case DevicePairingResultStatus::RequiredHandlerNotRegistered:
          status_message = "Required handler not registered";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::RejectedByHandler:
          status_message = "Rejected by handler";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::RemoteDeviceHasAssociation:
          status_message = "Remote device has association";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << std::endl;
          break;
        case DevicePairingResultStatus::Failed:
        default:
          status_message = "Failed with unknown status";
          std::cerr << "[WindowsPairing] ERROR STATUS: " << status_message << " (code=" << (int)status << ")" << std::endl;
          
          // Special handling for undocumented status codes
          if ((int)status == 19) {
            std::cerr << "\n[WindowsPairing] *** STATUS CODE 19 ANALYSIS ***" << std::endl;
            std::cerr << "[WindowsPairing] This is an undocumented Windows error" << std::endl;
            std::cerr << "[WindowsPairing] Likely causes:" << std::endl;
            std::cerr << "[WindowsPairing]   1. Too many pairing attempts in short time" << std::endl;
            std::cerr << "[WindowsPairing]   2. Previous pairing operation not fully cleaned up" << std::endl;
            std::cerr << "[WindowsPairing]   3. Windows BLE stack internal rate limiting" << std::endl;
            std::cerr << "[WindowsPairing]   4. Pairing event handler was not triggered" << std::endl;
            std::cerr << "[WindowsPairing] Solutions:" << std::endl;
            std::cerr << "[WindowsPairing]   - Wait 30-60 seconds before retry" << std::endl;
            std::cerr << "[WindowsPairing]   - Remove device from Windows Settings > Bluetooth" << std::endl;
            std::cerr << "[WindowsPairing]   - Restart Raspberry Pi Bluetooth service" << std::endl;
            std::cerr << "[WindowsPairing]   - Restart this application" << std::endl;
            std::cerr << "[WindowsPairing] ***********************************\n" << std::endl;
          }
          break;
      }

      std::cerr << "\n========================================" << std::endl;
      std::cerr << "[WindowsPairing] PAIRING COMPLETED" << std::endl;
      std::cerr << "[WindowsPairing] Final result: " << (success ? "SUCCESS" : "FAILURE") << std::endl;
      std::cerr << "[WindowsPairing] Message: " << status_message << std::endl;
      std::cerr << "========================================\n" << std::endl;

      if (!success) {
        result->Error("PAIRING_FAILED", status_message);
      } else {
        result->Success(flutter::EncodableValue(true));
      }

      // Clean up COM for this thread
      uninit_apartment();
    }
    catch (const hresult_error& ex) {
      std::string error_message = WideStringToUtf8(ex.message());
      result->Error("PAIRING_FAILED", error_message);
      try { uninit_apartment(); } catch (...) {}
    }
    catch (const std::exception& ex) {
      result->Error("PAIRING_FAILED", ex.what());
      try { uninit_apartment(); } catch (...) {}
    }
    catch (...) {
      result->Error("PAIRING_FAILED", "Unknown error occurred during pairing");
      try { uninit_apartment(); } catch (...) {}
    }
  }).detach(); // Detach thread to run independently
}

void WindowsBlePairingPlugin::IsDevicePaired(
    const std::string& device_address,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // IsDevicePaired is a READ-ONLY operation, it should NOT block or be blocked
  // by pairing operations. Only PairDevice and UnpairDevice should use active_operations_.
  // This allows Dart code to check pairing status before calling pairDevice().
  
  // Execute on background thread for thread safety and non-blocking operation
  std::thread([device_address, result = std::move(result)]() mutable {
    try {
      // Initialize COM for this background thread (MTA mode)
      init_apartment(apartment_type::multi_threaded);

      uint64_t bluetooth_address = WindowsBlePairingPlugin::MacStringToBluetoothAddress(device_address);
    if (bluetooth_address == 0) {
      result->Error("INVALID_ADDRESS", "Invalid Bluetooth address format");
        uninit_apartment();
      return;
    }

      // Query device asynchronously
    auto ble_device_async = BluetoothLEDevice::FromBluetoothAddressAsync(bluetooth_address);
    auto ble_device = ble_device_async.get();

    if (!ble_device) {
      result->Success(flutter::EncodableValue(false));
        uninit_apartment();
      return;
    }

      // Get pairing information
    auto device_info = ble_device.DeviceInformation();
    auto pairing_info = device_info.Pairing();

      bool is_paired = pairing_info.IsPaired();
      result->Success(flutter::EncodableValue(is_paired));

      // Clean up COM
      uninit_apartment();
    }
    catch (const hresult_error& ex) {
      std::string error_message = WideStringToUtf8(ex.message());
      result->Error("CHECK_FAILED", error_message);
      try { uninit_apartment(); } catch (...) {}
    }
    catch (const std::exception& ex) {
      result->Error("CHECK_FAILED", ex.what());
      try { uninit_apartment(); } catch (...) {}
  }
  catch (...) {
    result->Success(flutter::EncodableValue(false));
      try { uninit_apartment(); } catch (...) {}
  }
  }).detach();
}

void WindowsBlePairingPlugin::UnpairDevice(
    const std::string& device_address,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Check if operation is already in progress for this device
  {
    std::lock_guard<std::mutex> lock(pairing_mutex_);
    if (active_operations_[device_address]) {
      result->Error("OPERATION_IN_PROGRESS", 
                   "An operation is already in progress for this device");
      return;
    }
    // Mark operation as active
    active_operations_[device_address] = true;
  }
  
  // Execute on background thread for thread safety and non-blocking operation
  std::thread([device_address, result = std::move(result)]() mutable {
    // RAII guard to ensure operation flag is cleared
    struct OperationGuard {
      std::string address;
      ~OperationGuard() {
        std::lock_guard<std::mutex> lock(WindowsBlePairingPlugin::pairing_mutex_);
        WindowsBlePairingPlugin::active_operations_[address] = false;
      }
    } guard{device_address};
    
    try {
      // Initialize COM for this background thread (MTA mode)
      init_apartment(apartment_type::multi_threaded);

      uint64_t bluetooth_address = WindowsBlePairingPlugin::MacStringToBluetoothAddress(device_address);
      if (bluetooth_address == 0) {
        result->Error("INVALID_ADDRESS", "Invalid Bluetooth address format");
        uninit_apartment();
      return;
    }

      // Query device asynchronously
    auto ble_device_async = BluetoothLEDevice::FromBluetoothAddressAsync(bluetooth_address);
    auto ble_device = ble_device_async.get();

    if (!ble_device) {
      result->Success(flutter::EncodableValue(false));
        uninit_apartment();
      return;
    }

      // Get pairing information
    auto device_info = ble_device.DeviceInformation();
    auto pairing_info = device_info.Pairing();

      // If already unpaired, consider it success
    if (!pairing_info.IsPaired()) {
      result->Success(flutter::EncodableValue(true));
        uninit_apartment();
      return;
    }

      // Attempt to unpair the device
    auto unpair_result = pairing_info.UnpairAsync().get();
    bool success = (unpair_result.Status() == DeviceUnpairingResultStatus::Unpaired ||
                   unpair_result.Status() == DeviceUnpairingResultStatus::AlreadyUnpaired);

    result->Success(flutter::EncodableValue(success));

      // Clean up COM
      uninit_apartment();
  }
  catch (const hresult_error& ex) {
    std::string error_message = WideStringToUtf8(ex.message());
    result->Error("UNPAIR_FAILED", error_message);
      try { uninit_apartment(); } catch (...) {}
    }
    catch (const std::exception& ex) {
      result->Error("UNPAIR_FAILED", ex.what());
      try { uninit_apartment(); } catch (...) {}
  }
  catch (...) {
    result->Error("UNPAIR_FAILED", "Unknown error occurred during unpairing");
      try { uninit_apartment(); } catch (...) {}
  }
  }).detach();
}

}  // namespace windows_ble_pairing
