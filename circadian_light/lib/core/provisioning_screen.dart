import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

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
    final provisioner = Provisioner.espTouch();

    provisioner.listen((response) {
      Navigator.of(context).pop(response);
    });

    provisioner.start(ProvisioningRequest.fromStrings(
      ssid: ssidController.text,
      bssid: '00:00:00:00:00:00',
      password: passwordController.text,
    ));

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

    if(provisioner.running) {
      provisioner.stop();
    }

    if (response != null) {
      _onDeviceProvisioned(response);
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Device provisioned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Device successfully connected to the ${ssidController.text} network'),
              SizedBox.fromSize(size: const Size.fromHeight(20)),
              const Text('Device:'),
              Text('IP: ${response.ipAddressText}'),
              Text('BSSID: ${response.bssidText}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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

    return Center(
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
    );
  }

  @override
  void dispose() {
    ssidController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}