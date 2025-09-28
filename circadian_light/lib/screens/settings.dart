import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/provisioning_screen.dart';
import '../core/esp_connection.dart';
import '../core/sunrise_sunset_manager.dart';
import '../core/theme_manager.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../models/user_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isConnected = false;
  bool _sunriseSunsetEnabled = false;
  bool _hasLocationPermission = false;
  UserSettings? _userSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await db.initialize();
      final settings = await db.getUserSettings();
      _checkConnection();

      // Check location permission status
      final hasLocationPermission = await LocationService.I.checkLocationPermission();

      setState(() {
        _userSettings = settings;
        _sunriseSunsetEnabled = settings.sunriseSunsetEnabled;
        _hasLocationPermission = hasLocationPermission;
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
        await db.saveUserSettings(updatedSettings);
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

  Future<void> _launchHelpCenter() async {
    final Uri url = Uri.parse('https://docs.flutter.dev/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch help center')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ThemeManager.I.neumorphicGradient,
                ),
                boxShadow: ThemeManager.I.neumorphicShadows,
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
                            Text(
                              'Lamp Connection',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
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
                                color: _isConnected ? ThemeManager.I.successColor : ThemeManager.I.errorColor,
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
                          color: ThemeManager.I.elevatedSurfaceColor,
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(2, 2),
                              blurRadius: 8,
                              color: ThemeManager.I.isDarkMode
                                  ? const Color(0x20000000)
                                  : const Color(0x0A000000),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _checkConnection,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Text(
                                'Refresh',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: ThemeManager.I.secondaryTextColor,
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ThemeManager.I.neumorphicGradient,
                ),
                boxShadow: ThemeManager.I.neumorphicShadows,
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
                            Text(
                              'Sun Sync',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _sunriseSunsetEnabled
                                ? 'Automatically adjusts lamp brightness'
                                : 'Manual control enabled',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: ThemeManager.I.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: _sunriseSunsetEnabled,
                        onChanged: (value) async {
                          if (value) {
                            // When enabling Sun Sync, automatically request location permission
                            final messenger = ScaffoldMessenger.of(context);

                            if (!_hasLocationPermission) {
                              final granted = await LocationService.I.requestLocationPermission();
                              if (!mounted) return;

                              if (granted) {
                                setState(() {
                                  _hasLocationPermission = true;
                                  _sunriseSunsetEnabled = true;
                                });
                                SunriseSunsetManager.I.enable();
                                await SunriseSunsetManager.I.setLocationBasedTimes(true);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Sun Sync enabled with location-based sunrise/sunset times!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Location permission is required for Sun Sync. You can enable it in Settings.'),
                                    backgroundColor: Colors.orange,
                                    action: SnackBarAction(
                                      label: 'Settings',
                                      onPressed: () {
                                        LocationService.I.openLocationSettings();
                                      },
                                    ),
                                  ),
                                );
                                return; // Don't enable Sun Sync if location permission denied
                              }
                            } else {
                              // Already have permission, just enable Sun Sync
                              setState(() {
                                _sunriseSunsetEnabled = true;
                              });
                              SunriseSunsetManager.I.enable();
                              await SunriseSunsetManager.I.setLocationBasedTimes(true);
                            }
                          } else {
                            // Disable Sun Sync
                            setState(() {
                              _sunriseSunsetEnabled = false;
                            });
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
                        color: ThemeManager.I.infoBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2),
                            blurRadius: 8,
                            color: ThemeManager.I.isDarkMode
                                ? const Color(0x20000000)
                                : const Color(0x0A000000),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Status: ${SunriseSunsetManager.I.getCurrentStatus()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: ThemeManager.I.primaryTextColor,
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
            // Dark Mode Toggle Card
            ListenableBuilder(
              listenable: ThemeManager.I,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: ThemeManager.I.neumorphicGradient,
                    ),
                    boxShadow: ThemeManager.I.neumorphicShadows,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: ThemeManager.I.isDarkMode
                              ? [const Color(0xFF6A5ACD), const Color(0xFF9370DB)]
                              : [const Color(0xFFFFB347), const Color(0xFFFFD700)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (ThemeManager.I.isDarkMode ? Colors.deepPurple : Colors.amber).withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          ThemeManager.I.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ThemeManager.I.isDarkMode
                                ? 'Dark theme is active'
                                : 'Light theme is active',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: ThemeManager.I.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch(
                        value: ThemeManager.I.isDarkMode,
                        onChanged: (value) async {
                          await ThemeManager.I.setDarkMode(value);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // HELP Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'HELP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: ThemeManager.I.secondaryTextColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Help Center Card
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ThemeManager.I.neumorphicGradient,
                ),
                boxShadow: ThemeManager.I.neumorphicShadows,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _launchHelpCenter,
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
                              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            'Help Center',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: ThemeManager.I.primaryTextColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: ThemeManager.I.secondaryTextColor,
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
      ),
    );
  }
}