import 'package:flutter/material.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';
import 'package:network_info_plus/network_info_plus.dart';

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
  
  // Create logger instance
  final Logger _logger = Logger('ProvisioningScreen');

  @override
  void initState() {
    super.initState();
    _logger.info('ProvisioningScreen initState() called');
    
    // Verbose logs from esp_smartconfig to the console
    Logger.root.level = Level.ALL;
    _logger.info('Logger level set to: ${Logger.root.level}');
    
    Logger.root.onRecord.listen((r) {
      // Keep it light: print level, logger name, and message
      // Useful to confirm packets are being sent while ESP waits with dots
      // Example: [esp_smartconfig][INFO] Sending...
      // ignore: avoid_print
      print('📋 [${r.loggerName}][${r.level.name}] ${r.message}');
      
      // Extra debug for important messages
      if (r.message.toLowerCase().contains('send') || 
          r.message.toLowerCase().contains('packet') ||
          r.message.toLowerCase().contains('start') ||
          r.message.toLowerCase().contains('stop')) {
        // ignore: avoid_print
        print('🔍 [IMPORTANT] ${r.message}');
      }
    });
    
    if (Platform.isIOS) {
      _logger.info('Checking iOS device info...');
      DeviceInfoPlugin().iosInfo.then((info) {
        final isSim = !info.isPhysicalDevice;
        _logger.info('iOS device - isPhysicalDevice: ${info.isPhysicalDevice}');
        if (mounted) {
          setState(() {
            _isSim = isSim;
          });
        }
      });
    } else {
      _logger.info('Platform is not iOS');
    }
  }

  Future<void> _testNetworkConnectivity() async {
    _logger.info('Testing network connectivity...');
    
    // Test basic internet connectivity
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _logger.info('Internet connectivity: OK');
      }
    } catch (e) {
      _logger.severe('Internet connectivity failed: $e');
    }
    
    // Get current network info
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();
      final wifiIP = await info.getWifiIP();
      final wifiBSSID = await info.getWifiBSSID();
      
      _logger.info('Current WiFi Network:');
      _logger.info('  Name: $wifiName');
      _logger.info('  IP: $wifiIP');
      _logger.info('  BSSID: $wifiBSSID');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Network Info:'),
                Text('WiFi: ${wifiName ?? "Unknown"}'),
                Text('IP: ${wifiIP ?? "Unknown"}'),
                Text('BSSID: ${wifiBSSID ?? "Unknown"}'),
                const SizedBox(height: 8),
                const Text('⚠️ Ensure ESP32 is on same 2.4GHz network!'),
              ],
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      _logger.severe('Network info failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Network info failed: $e')),
        );
      }
    }
  }

  Future<void> _startProvisioning() async {
    _logger.info('Starting provisioning process...');
    _logger.info('SSID: ${ssidController.text}');
    _logger.info('Password length: ${passwordController.text.length} chars');
    
    // Use original EspTouch for compatibility with ESP32 SC_TYPE_ESPTOUCH_AIRKISS
    final provisioner = Provisioner.espTouch();
    _logger.info('Provisioner created (EspTouch type)');

    int responseCount = 0;
    provisioner.listen((response) {
      responseCount++;
      _logger.info('Response #$responseCount received from ESP32:');
      _logger.info('IP: ${response.ipAddressText}');
      _logger.info('BSSID: ${response.bssidText}');
      if (mounted) {
        Navigator.of(context).pop(response);
      }
    });

    _logger.info('Starting provisioning with request...');
    final request = ProvisioningRequest.fromStrings(
      ssid: ssidController.text,
      password: passwordController.text,
    );
    _logger.info('Request created - SSID: ${request.ssid}');
    
    // Add timing
    final startTime = DateTime.now();
    _logger.info('Provisioning started at: ${startTime.toIso8601String()}');
    
    provisioner.start(request);
    _logger.info('Provisioner.start() called - packets should be transmitting now');

    ProvisioningResponse? response;
    
    if (mounted) {
      response = await showDialog<ProvisioningResponse>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Provisioning'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Sending SmartConfig packets...'),
                const SizedBox(height: 8),
                Text('SSID: ${ssidController.text}'),
                const Text('Check ESP32 serial monitor for "[SC]" messages'),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  _logger.warning('User stopped provisioning');
                  Navigator.of(context).pop();
                },
                child: const Text('Stop'),
              ),
            ],
          );
        },
      );
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    _logger.info('Provisioning dialog closed after: ${duration.inSeconds}s');

    if(provisioner.running) {
      _logger.info('Stopping provisioner...');
      provisioner.stop();
      _logger.info('Provisioner stopped');
    } else {
      _logger.warning('Provisioner was not running when dialog closed');
    }

    if (response != null) {
      _logger.info('Provisioning successful! Calling _onDeviceProvisioned');
      _onDeviceProvisioned(response);
    } else {
      _logger.warning('Provisioning failed or was cancelled');
    }
  }

  void _onDeviceProvisioned(ProvisioningResponse response) {
    _logger.info('_onDeviceProvisioned called with response:');
    _logger.info('IP: ${response.ipAddressText}');
    _logger.info('BSSID: ${response.bssidText}');
    _logger.fine('Raw response: $response');
    
    if (!mounted) return;
    
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
                _logger.info('User confirmed successful provisioning - closing dialogs');
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
  Widget build(BuildContext context) {
    final bool blocked = Platform.isIOS && _isSim;
    _logger.fine('Building ProvisioningScreen - blocked: $blocked, platform: ${Platform.operatingSystem}');

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
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _testNetworkConnectivity,
                child: const Text('Test Network Connectivity'),
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