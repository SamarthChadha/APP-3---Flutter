import 'package:flutter/material.dart';
import 'esp_connection.dart';
import 'provisioning_screen.dart';

class ConnectionManager extends StatefulWidget {
  final Widget child;
  
  const ConnectionManager({super.key, required this.child});

  @override
  State<ConnectionManager> createState() => _ConnectionManagerState();
}

class _ConnectionManagerState extends State<ConnectionManager> {
  bool _isConnected = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);
    
    // Try to connect to ESP32
    try {
      await EspConnection.I.connect();
      await Future.delayed(const Duration(seconds: 3)); // Give it time to connect
      
      if (mounted) {
        setState(() {
          _isConnected = EspConnection.I.isConnected;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _startProvisioning() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const Scaffold(
          body: ProvisioningScreen(title: 'Connect ESP32'),
        ),
      ),
    );
    
    if (result == true) {
      // Provisioning successful, try to connect
      _checkConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Checking ESP32 connection...'),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() {
                  _isConnected = false;
                  _isChecking = false;
                }),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 20),
                const Text(
                  'ESP32 not connected',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Set up your device to connect to WiFi',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: _startProvisioning,
                  child: const Text('Connect Device'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _checkConnection,
                  child: const Text('Check Connection Again'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => _isConnected = true),
                  child: const Text('Skip (for testing)'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }

  @override
  void dispose() {
    EspConnection.I.close();
    super.dispose();
  }
}
