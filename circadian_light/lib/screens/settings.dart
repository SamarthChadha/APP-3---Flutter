import 'package:flutter/material.dart';
import '../core/provisioning_screen.dart';
import '../core/esp_connection.dart';
import '../core/sunrise_sunset_manager.dart';
import '../services/storage_service.dart';
import '../models/user_settings.dart';
import 'shared_prefs_test.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnected = false;
  bool _sunriseSunsetEnabled = false;
  UserSettings? _userSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await storage.initialize();
      final settings = await storage.getUserSettings();
      _checkConnection();
      
      setState(() {
        _userSettings = settings;
        _sunriseSunsetEnabled = settings.sunriseSunsetEnabled;
      });
      
      // Update the sunrise/sunset manager state
      if (_sunriseSunsetEnabled) {
        SunriseSunsetManager.I.enable();
      } else {
        SunriseSunsetManager.I.disable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_userSettings != null) {
      try {
        final updatedSettings = _userSettings!.copyWith(
          sunriseSunsetEnabled: _sunriseSunsetEnabled,
        );
        await storage.saveUserSettings(updatedSettings);
        setState(() {
          _userSettings = updatedSettings;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving settings: $e')),
          );
        }
      }
    }
  }

  void _checkConnection() {
    setState(() {
      _isConnected = EspConnection.I.isConnected;
    });
  }

  Future<void> _reconnectDevice() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ProvisioningScreen(title: 'Reconnect to Circadian Lamp'),
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
            // Neumorphic style ESP32 connection card
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFDFD), Color(0xFFE3E3E3)],
                ),
                boxShadow: const [
                  BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
                  BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: _isConnected 
                              ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                              : [const Color(0xFFEF5350), const Color(0xFFE57373)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? Colors.green : Colors.red).withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lamp Connection',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isConnected 
                                ? 'Device is connected and ready'
                                : 'Device is not connected',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: _isConnected ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFC049), Color(0xFFFFD700)],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                offset: Offset(2, 2),
                                blurRadius: 8,
                                color: Color(0x1A000000),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _reconnectDevice,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    _isConnected ? 'Reconfigure WiFi' : 'Connect Device',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Color(0xFF3C3C3C),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFFF5F5F5),
                          boxShadow: const [
                            BoxShadow(
                              offset: Offset(2, 2),
                              blurRadius: 8,
                              color: Color(0x0A000000),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _checkConnection,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Text(
                                'Refresh',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Neumorphic style card matching routine cards
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFDFD), Color(0xFFE3E3E3)],
                ),
                boxShadow: const [
                  BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
                  BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFF8C00), Color(0xFFFFB347)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.wb_sunny,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sunrise & Sunset Sync',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _sunriseSunsetEnabled 
                                ? 'Automatically adjusts lamp brightness'
                                : 'Manual control enabled',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: Color(0xFF5A5A5A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _sunriseSunsetEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _sunriseSunsetEnabled = value;
                          });
                          
                          if (value) {
                            SunriseSunsetManager.I.enable();
                          } else {
                            SunriseSunsetManager.I.disable();
                          }
                          
                          await _saveSettings();
                        },
                      ),
                    ],
                  ),
                  if (_sunriseSunsetEnabled) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(2, 2),
                            blurRadius: 8,
                            color: Color(0x0A000000),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Status: ${SunriseSunsetManager.I.getCurrentStatus()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF2F2F2F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sunrise',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  Text(
                                    SunriseSunsetManager.I.sunriseTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2F2F2F),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Sunset',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  Text(
                                    SunriseSunsetManager.I.sunsetTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2F2F2F),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            // SharedPreferences Test Button
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFDFD), Color(0xFFE3E3E3)],
                ),
                boxShadow: const [
                  BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
                  BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SharedPrefsTestScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.storage,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 18),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Test SharedPreferences Storage',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2F2F2F),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Test JSON serialization storage technique',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  color: Color(0xFF5A5A5A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF999999),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}