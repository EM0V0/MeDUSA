import 'package:flutter/material.dart';
import '../../../../shared/services/winble_service.dart';
import '../../../../shared/services/winble_wifi_helper_service.dart';

/// Test page for WinBle + WinRT pairing
/// 
/// This page demonstrates the complete flow:
/// 1. Scan for devices
/// 2. Connect
/// 3. Pair (Windows PIN dialog)
/// 4. Provision WiFi
class WinBleTestPage extends StatefulWidget {
  const WinBleTestPage({super.key});

  @override
  State<WinBleTestPage> createState() => _WinBleTestPageState();
}

class _WinBleTestPageState extends State<WinBleTestPage> {
  final WinBleService _winBle = WinBleService();
  final WinBleWiFiHelperService _wifiHelper = WinBleWiFiHelperService();

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<BleDevice> _devices = [];
  BleDevice? _selectedDevice;
  bool _isScanning = false;
  String _status = 'Idle';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _winBle.initialize();
    
    // Listen to device stream
    _winBle.devicesStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    // Listen to status
    _winBle.addListener(() {
      setState(() {
        _status = _winBle.status;
      });
    });

    _wifiHelper.addListener(() {
      setState(() {
        _status = _wifiHelper.status;
      });
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    await _winBle.startScan(
      timeout: const Duration(seconds: 30),
      nameFilter: 'medusa',
    );

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _stopScan() async {
    await _winBle.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _provisionWiFi() async {
    if (_selectedDevice == null) {
      _showMessage('Please select a device first');
      return;
    }

    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Please enter SSID and password');
      return;
    }

    final success = await _wifiHelper.provisionWiFi(
      deviceAddress: _selectedDevice!.address,
      ssid: _ssidController.text,
      password: _passwordController.text,
    );

    if (success) {
      _showMessage('✅ WiFi provisioning successful!');
    } else {
      _showMessage('❌ WiFi provisioning failed');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WinBle Test - WiFi Provisioning'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Status: $_status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan button
            ElevatedButton.icon(
              onPressed: _isScanning ? _stopScan : _startScan,
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
            ),
            const SizedBox(height: 16),

            // Device list
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text('No devices found.\nTap "Scan" to start.'),
                    )
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = _selectedDevice?.address == device.address;

                        return Card(
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: isSelected ? Colors.blue : null,
                            ),
                            title: Text(device.name),
                            subtitle: Text(device.address),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.blue)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedDevice = device;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // WiFi credentials
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'WiFi SSID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'WiFi Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),

            // Provision button
            ElevatedButton.icon(
              onPressed: _selectedDevice != null ? _provisionWiFi : null,
              icon: const Icon(Icons.send),
              label: const Text('Provision WiFi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 8),

            // Instructions
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Instructions:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Click "Scan for Devices"'),
                    const Text('2. Select a device from the list'),
                    const Text('3. Enter WiFi credentials'),
                    const Text('4. Click "Provision WiFi"'),
                    const Text('5. 🪟 Windows PIN dialog will appear'),
                    const Text('6. 📱 Check Pi OLED for 6-digit PIN'),
                    const Text('7. Enter PIN in Windows dialog'),
                    const Text('8. Wait for provisioning to complete'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

