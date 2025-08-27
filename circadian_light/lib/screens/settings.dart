import 'package:flutter/material.dart';
import '../core/provisioning_screen.dart';
import '../core/esp_connection.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  void _checkConnection() {
    setState(() {
      _isConnected = EspConnection.I.isConnected;
    });
  }

  Future<void> _reconnectDevice() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ProvisioningScreen(title: 'Reconnect ESP32'),
      ),
    );
    
    if (result == true) {
      _checkConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ESP32 Connection',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected 
                        ? 'Device is connected and ready'
                        : 'Device is not connected',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _reconnectDevice,
                          child: Text(_isConnected ? 'Reconfigure WiFi' : 'Connect Device'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _checkConnection,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}