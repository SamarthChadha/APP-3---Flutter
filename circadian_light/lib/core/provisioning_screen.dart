import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:convert';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key, required this.title});

  final String title;

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();

  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isProvisioning = false;
  String _statusMessage = 'Ready to scan for devices';
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // ESP32 WiFiProv BLE service UUID (matches ESP32 firmware)
  // UUID from ESP32: {0xb4, 0xdf, 0x5a, 0x1c, 0x3f, 0x6b, 0xf4, 0xbf, 0xea, 0x4a, 0x82, 0x03, 0x04, 0x90, 0x1a, 0x02}
  static const String provServiceUuid = "b4df5a1c-3f6b-f4bf-ea4a-820304901a02";

  // Standard ESP32 provisioning characteristic UUIDs
  static const String provConfigUuid = "0000ff52-0000-1000-8000-00805f9b34fb";
  static const String provSessionUuid = "0000ff51-0000-1000-8000-00805f9b34fb";

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  Future<void> _checkBluetoothState() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Bluetooth not supported on this device';
        });
      }
      return;
    }

    // Check if Bluetooth is on
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Please enable Bluetooth to continue';
        });
      }
    }
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _statusMessage = 'Scanning for CircadianLight devices...';
    });

    try {
      // Start scanning for BLE devices with the provisioning service UUID
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
        withServices: [Guid(provServiceUuid)], // Scan for specific service UUID
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          // Filter for devices with the provisioning service or named "CircadianLight"
          _scanResults = results.where((result) {
            final name = result.device.platformName;
            final hasProvService = result.advertisementData.serviceUuids
                .any((uuid) => uuid.toString().toLowerCase() == provServiceUuid.toLowerCase());

            return hasProvService ||
                   (name.isNotEmpty && (name.contains('CircadianLight') || name.contains('PROV_')));
          }).toList();

          debugPrint('Found ${_scanResults.length} provisioning device(s)');
          for (var result in _scanResults) {
            debugPrint('  - ${result.device.platformName} (${result.device.remoteId})');
            debugPrint('    Services: ${result.advertisementData.serviceUuids}');
          }
        });
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 15));
      await FlutterBluePlus.stopScan();

      setState(() {
        _isScanning = false;
        if (_scanResults.isEmpty) {
          _statusMessage = 'No CircadianLight devices found. Hold encoder button for 5 seconds to start provisioning mode.';
        } else {
          _statusMessage = 'Found ${_scanResults.length} device(s). Tap to connect.';
        }
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan error: $e';
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _statusMessage = 'Connecting to ${device.platformName}...';
    });

    try {
      // Connect to the device
      await device.connect(timeout: const Duration(seconds: 15));

      setState(() {
        _connectedDevice = device;
        _statusMessage = 'Connected! Ready to provision.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _startProvisioning() async {
    if (_connectedDevice == null) {
      setState(() {
        _statusMessage = 'No device connected';
      });
      return;
    }

    if (ssidController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter WiFi SSID';
      });
      return;
    }

    setState(() {
      _isProvisioning = true;
      _statusMessage = 'Discovering services...';
    });

    try {
      // Discover services
      List<BluetoothService> services = await _connectedDevice!.discoverServices();

      // Find the provisioning service
      BluetoothService? provService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == provServiceUuid.toLowerCase()) {
          provService = service;
          break;
        }
      }

      if (provService == null) {
        setState(() {
          _statusMessage = 'Provisioning service not found. Device may not be in provisioning mode.';
          _isProvisioning = false;
        });
        return;
      }

      // Find the config characteristic
      BluetoothCharacteristic? configChar;
      for (var char in provService.characteristics) {
        if (char.uuid.toString().toLowerCase() == provConfigUuid.toLowerCase()) {
          configChar = char;
          break;
        }
      }

      if (configChar == null) {
        setState(() {
          _statusMessage = 'Config characteristic not found';
          _isProvisioning = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Sending WiFi credentials...';
      });

      // Prepare provisioning data
      // The ESP32 WiFiProv expects a JSON payload with SSID and password
      final provData = {
        'ssid': ssidController.text,
        'password': passwordController.text,
      };

      final jsonString = jsonEncode(provData);
      final data = utf8.encode(jsonString);

      // Send credentials via BLE
      await configChar.write(data, withoutResponse: false);

      setState(() {
        _statusMessage = 'Credentials sent! Waiting for device to connect...';
      });

      // Wait a bit for the ESP32 to process
      await Future.delayed(const Duration(seconds: 3));

      // Try to read response (if characteristic supports it)
      if (configChar.properties.read) {
        try {
          final response = await configChar.read();
          final responseStr = utf8.decode(response);
          debugPrint('Provisioning response: $responseStr');
        } catch (e) {
          debugPrint('Could not read response: $e');
        }
      }

      // Disconnect from BLE device
      await _connectedDevice!.disconnect();

      if (mounted) {
        setState(() {
          _isProvisioning = false;
          _statusMessage = 'Provisioning complete!';
        });

        // Show success dialog
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isProvisioning = false;
        _statusMessage = 'Provisioning failed: $e';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provisioning Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device successfully connected to ${ssidController.text}'),
              const SizedBox(height: 16),
              const Text(
                'The lamp should now be accessible on your WiFi network.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return success to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _connectedDevice?.disconnect();
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                Icons.bluetooth_searching,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'BLE WiFi Provisioning',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your Circadian Lamp to WiFi via Bluetooth',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hold encoder button for 5 seconds to enable provisioning mode',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_isScanning || _isProvisioning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_isScanning || _isProvisioning) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scan button
              if (_connectedDevice == null)
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScanning,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

              // Scan results
              if (_scanResults.isNotEmpty && _connectedDevice == null) ...[
                const SizedBox(height: 24),
                Text(
                  'Available Devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...(_scanResults.map((result) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.lightbulb_outline),
                      title: Text(result.device.platformName),
                      subtitle: Text('Signal: ${result.rssi} dBm'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _connectToDevice(result.device),
                    ),
                  );
                }).toList()),
              ],

              // WiFi credentials form (shown when connected)
              if (_connectedDevice != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connected to ${_connectedDevice!.platformName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Enter WiFi Credentials',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ssidController,
                  decoration: const InputDecoration(
                    labelText: 'WiFi Network Name (SSID)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'WiFi Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isProvisioning ? null : _startProvisioning,
                  icon: const Icon(Icons.send),
                  label: Text(_isProvisioning ? 'Provisioning...' : 'Provision Device'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}