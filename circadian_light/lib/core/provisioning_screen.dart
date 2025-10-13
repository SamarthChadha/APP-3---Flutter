// Screen for provisioning ESP32 device to WiFi network using ESP-Touch protocol

import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';

// Stateful widget for WiFi provisioning screen
class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key, required this.title});

  final String title;

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

// State class handling provisioning logic and UI
class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isSim = false;

  @override
  void initState() {
    super.initState();
    // Verbose logs from esp_smartconfig to the console
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((r) {
      // Keep it light: print level, logger name, and message
      // Useful to confirm packets are being sent while ESP waits with dots
      // Example: [esp_smartconfig][INFO] Sending...
      // ignore: avoid_print
      print('[${r.loggerName}][${r.level.name}] ${r.message}');
    });
    if (Platform.isIOS) {
      DeviceInfoPlugin().iosInfo.then((info) {
        final isSim = !info.isPhysicalDevice;
        if (mounted) {
          setState(() {
            _isSim = isSim;
          });
        }
      });
    }
  }

  // Start ESP-Touch provisioning process
  Future<void> _startProvisioning() async {
    // EspTouchV2 tends to be more reliable on modern phones/routers
    final provisioner = Provisioner.espTouchV2();

    provisioner.listen((response) {
      Navigator.of(context).pop(response);
    });

    provisioner.start(
      ProvisioningRequest.fromStrings(
        ssid: ssidController.text,
        // bssid is optional; library defaults to 00:00:00:00:00:00 internally
        password: passwordController.text,
      ),
    );

    ProvisioningResponse? response = await showDialog<ProvisioningResponse>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provisioning'),
          content: const Text('Provisioning started. Please wait...'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );

    if (provisioner.running) {
      provisioner.stop();
    }

    if (response != null) {
      _onDeviceProvisioned(response);
    }
  }

  // Handle successful device provisioning
  void _onDeviceProvisioned(ProvisioningResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Device provisioned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Device successfully connected to the '
                '${ssidController.text} network',
              ),
              SizedBox.fromSize(size: const Size.fromHeight(20)),
              const Text('Device:'),
              Text('IP: ${response.ipAddressText}'),
              Text('BSSID: ${response.bssidText}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(
                  context,
                ).pop(true); // Return success to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool blocked = Platform.isIOS && _isSim;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.cell_tower,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                blocked
                    ? 'SmartConfig needs a real iPhone '
                          '(the iOS Simulator has no Wi‑Fi).'
                    : 'Connect device to Wi‑Fi network using '
                          'ESP‑Touch protocol',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'SSID (Network name)',
                ),
                controller: ssidController,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                controller: passwordController,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: blocked ? null : _startProvisioning,
                child: const Text('Start provisioning'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
