import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key, required this.title});

  final String title;

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

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

  Future<void> _startProvisioning() async {
    Logger.root.info('Starting provisioning with SSID: ${ssidController.text}');

    final provisioner = Provisioner.espTouchV2();
    ProvisioningResponse? response;
    bool completed = false;

    // Listen for successful provisioning
    late final subscription = provisioner.listen((provisioningResponse) {
      Logger.root.info('Provisioning response received: ${provisioningResponse.ipAddressText}');
      if (!completed) {
        completed = true;
        response = provisioningResponse;
        Navigator.of(context).pop();
      }
    });

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provisioning Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Sending credentials to device...\n\nSSID: ${ssidController.text}'),
              const SizedBox(height: 8),
              const Text('Make sure your ESP32 is in SmartConfig mode',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                completed = true;
                subscription.cancel();
                provisioner.stop();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    try {
      Logger.root.info('Starting ESP-Touch V2 provisioning...');
      await provisioner.start(ProvisioningRequest.fromStrings(
        ssid: ssidController.text,
        password: passwordController.text,
      ));
      Logger.root.info('Provisioning started, waiting for response...');

      // Wait for 45 seconds maximum
      await Future.delayed(const Duration(seconds: 45));

      if (!completed) {
        completed = true;
        subscription.cancel();
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _showTimeoutDialog();
        }
      }

    } catch (e) {
      Logger.root.severe('Provisioning error: $e');
      completed = true;
      subscription.cancel();
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(e.toString());
      }
    } finally {
      if (provisioner.running) {
        provisioner.stop();
      }
    }

    if (response != null) {
      _onDeviceProvisioned(response!);
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Device connected to ${ssidController.text}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device IP: ${response.ipAddressText}',
                         style: const TextStyle(fontFamily: 'monospace')),
                    Text('BSSID: ${response.bssidText}',
                         style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return success to previous screen
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.timer_off, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Timeout'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('No response from device after 45 seconds.'),
              SizedBox(height: 12),
              Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Make sure ESP32 is powered on'),
              Text('• Check ESP32 serial output for SmartConfig status'),
              Text('• Verify ESP32 is in SmartConfig mode'),
              Text('• Try resetting ESP32 and retry'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Provisioning failed:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(error, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
                    ? 'SmartConfig needs a real iPhone (the iOS Simulator has no Wi‑Fi).'
                    : 'Connect device to Wi‑Fi network using ESP‑Touch protocol',
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
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
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