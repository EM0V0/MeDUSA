# MeDUSA Mobile App (Flutter)

The patient and doctor mobile interface for the MeDUSA (Medical Data Unified System & Analytics) platform.

## 📱 Features

- **Tremor Monitoring**: Real-time bluetooth connectivity with tremor sensors.
- **Data Visualization**: Live charts for raw sensor data (X/Y/Z) and spectral analysis.
- **Doctor Portal**: Dashboard for doctors to view assigned patients and their telemetry.
- **Secure Networking**: Certificate handling via System Trust Store (`secure_network_service.dart`).

## 🔵 Bluetooth Support

| Platform | Implementation | Notes |
|----------|---------------|-------|
| **Windows** | WinBLE + FlutterBluePlus | Full support: scan, pair, provision |
| **Web** | Web Bluetooth API | Chrome/Edge/Opera only, requires HTTPS |
| **Android/iOS** | FlutterBluePlus | Standard mobile BLE |

### Web Bluetooth Limitations
- Requires **HTTPS** or **localhost** (secure context)
- Only supported in **Chrome, Edge, Opera** (Chromium-based)
- **User interaction required** - no background scanning
- Safari and Firefox are NOT supported

## 🛠 Prerequisites

- Flutter SDK (3.0+)
- Android Studio / Xcode
- VS Code (Recommended)

## 🚀 Getting Started

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run in Debug Mode**
   ```bash
   flutter run
   ```

3. **Build Release**
   ```bash
   # Android
   flutter build apk --release --obfuscate --split-debug-info=./debug-info

   # iOS
   flutter build ios --release
   ```

## 🔐 Security Notes

- **API Endpoints**: Configured in `lib/shared/config/app_config.dart` (or similar).
- **SSL/TLS**: Uses the device's system root certificates. Ensure your emulator/device date and time are correct.
