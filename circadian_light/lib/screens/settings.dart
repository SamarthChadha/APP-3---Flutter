import 'package:flutter/material.dart';
import '../core/provisioning_screen.dart';
import '../core/esp_connection.dart';
import '../core/sunrise_sunset_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnected = false;
  bool _sunriseSunsetEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _sunriseSunsetEnabled = SunriseSunsetManager.I.isEnabled;
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Sunrise & Sunset Sync',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sunriseSunsetEnabled 
                        ? 'Automatically adjusts lamp brightness based on sunrise and sunset times'
                        : 'Manual control enabled',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Enable Sunrise/Sunset Sync'),
                        Switch(
                          value: _sunriseSunsetEnabled,
                          onChanged: (value) {
                            setState(() {
                              _sunriseSunsetEnabled = value;
                              if (value) {
                                SunriseSunsetManager.I.enable();
                              } else {
                                SunriseSunsetManager.I.disable();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_sunriseSunsetEnabled) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status: ${SunriseSunsetManager.I.getCurrentStatus()}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sunrise: ${SunriseSunsetManager.I.sunriseTime.format(context)} • '
                              'Sunset: ${SunriseSunsetManager.I.sunsetTime.format(context)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Note: When enabled, all other routines are disabled.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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