import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:circadian_light/core/esp_connection.dart';
import 'package:circadian_light/models/lamp_state.dart';
import 'package:circadian_light/services/database_service.dart';
import '../core/theme_manager.dart';
// import 'package:flutter_gl/flutter_gl.dart';
// import 'package:flutter_3d_controller/'


// void loadMyShader() async {
//   var program = await FragmentProgram.fromAsset('assets/shaders/lamp_shader.frag');
// }


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOn = true;
  double _brightness = 0.7; // 0..1
  double _tempK = 2800;     // 1800..6500

  // Debounce timers for sliders
  Timer? _brightTimer;
  Timer? _tempTimer;
  
  // Stream subscription for ESP state updates
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _loadStateFromDatabase();
    
    // Listen for ESP connection changes
    EspConnection.I.connection.listen((isConnected) {
      if (isConnected) {
        // When ESP reconnects, request its current state
        Timer(const Duration(milliseconds: 1000), () {
          EspConnection.I.requestCurrentState();
        });
      }
    });
    
    // Listen for state updates from ESP32
    _stateSubscription = EspConnection.I.stateUpdates.listen((state) {
      setState(() {
        _isOn = state.isOn;
        _brightness = state.flutterBrightness;
        _tempK = state.flutterTemperature;
      });
      
      // Save state when ESP updates (sync ESP state to database)
      _saveStateToDatabase();
      debugPrint('Synced ESP state to app: isOn=${state.isOn}, brightness=${state.brightness}, mode=${state.mode}');
    });
  }

  /// Load saved lamp state from database on startup
  Future<void> _loadStateFromDatabase() async {
    try {
      final lampState = await db.getLampState();
      setState(() {
        _isOn = lampState.isOn;
        _brightness = lampState.flutterBrightness;
        _tempK = lampState.flutterTemperature;
      });
      
      // Sync loaded state to ESP if connected
      if (EspConnection.I.isConnected) {
        EspConnection.I.setOn(_isOn);
        EspConnection.I.setBrightness(_mapBrightnessTo15(_brightness));
        EspConnection.I.setMode(_modeFromTemp(_tempK));
      }
    } catch (e) {
      debugPrint('Error loading lamp state: $e');
    }
  }

  /// Save current lamp state to database
  Future<void> _saveStateToDatabase() async {
    try {
      final lampState = LampState.fromFlutterValues(
        isOn: _isOn,
        brightness: _brightness,
        temperature: _tempK,
      );
      await db.saveLampState(lampState);
    } catch (e) {
      debugPrint('Error saving lamp state: $e');
    }
  }

  @override
  void dispose() {
    _brightTimer?.cancel();
    _tempTimer?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  int _mapBrightnessTo15(double v) {
    // Map 0.0-1.0 to 1-15 (minimum brightness 1 when LEDs are on)
    final val = ((v.clamp(0.0, 1.0) * 14) + 1).round();
    return val.clamp(1, 15);
  }

  int _modeFromTemp(double k) {
    // Simple split: <=3000 warm (0), >=5000 white (1), else both (2)
    if (k <= 3000) return 0; // MODE_WARM
    if (k >= 5000) return 1; // MODE_WHITE
    return 2; // MODE_BOTH
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 55),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Connection status row
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: StreamBuilder<bool>(
                  initialData: EspConnection.I.isConnected,
                  stream: EspConnection.I.connection,
                  builder: (context, snap) {
                    final ok = snap.data == true;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: ok ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ok ? 'Connected' : 'Disconnected',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // const Text('Hi This is home Screen'),
              NeumorphicPanel(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationX(3.1416),
                  child: const Flutter3DViewer(src: 'assets/models/Textured_Lamp_Small.glb'),
                ),
              ),
              const SizedBox(height: 24),
              // Main Power Toggle
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isOn = !_isOn);
                    EspConnection.I.setOn(_isOn);
                    _saveStateToDatabase(); // Save state when user toggles
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      color: _isOn ? const Color(0xFFFFC049) : const Color(0xFFE0E0E0),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                        BoxShadow(
                          offset: const Offset(-1, -1),
                          blurRadius: 3,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _isOn ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Color Temperature Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ControlCard(
                  icon: Icons.thermostat,
                  iconGradient: const [Color(0xFFFFC477), Color(0xFFFFD700)],
                  title: 'Color Temperature',
                  subtitle: '${_tempK.round()}K - ${_tempK <= 3000 ? 'Warm' : _tempK >= 5000 ? 'Cool' : 'Mixed'}',
                  control: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFFFC477), // warm
                              Color(0xFFBFD7FF), // cool
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(2, 2),
                              blurRadius: 6,
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                            BoxShadow(
                              offset: const Offset(-2, -2),
                              blurRadius: 6,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 18,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: const Color(0xFFEFEFEF),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                        ),
                        child: Slider(
                          min: 2700,
                          max: 6500,
                          value: _tempK,
                          onChanged: (v) {
                            setState(() => _tempK = v);
                            _tempTimer?.cancel();
                            _tempTimer = Timer(const Duration(milliseconds: 80), () {
                              EspConnection.I.setMode(_modeFromTemp(_tempK));
                              _saveStateToDatabase(); // Save state when user changes temperature
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Brightness Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ControlCard(
                  icon: Icons.brightness_6,
                  iconGradient: const [Color(0xFFFFC049), Color(0xFFFFD700)],
                  title: 'Brightness',
                  subtitle: '${(_brightness * 100).round()}% intensity',
                  control: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(2, 2),
                              blurRadius: 6,
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                            BoxShadow(
                              offset: const Offset(-2, -2),
                              blurRadius: 6,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 18,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: const Color(0xFFEFEFEF),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: 1.0,
                          value: _brightness,
                          onChanged: (v) {
                            setState(() => _brightness = v);
                            _brightTimer?.cancel();
                            _brightTimer = Timer(const Duration(milliseconds: 60), () {
                              final b = _mapBrightnessTo15(_brightness);
                              EspConnection.I.setBrightness(b);
                              _saveStateToDatabase(); // Save state when user changes brightness
                            });
                          },
                        ),
                      ),
                    ],
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

class NeumorphicPillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color; // custom base color
  const NeumorphicPillButton({super.key, required this.label, required this.onTap, this.color});

  @override
  State<NeumorphicPillButton> createState() => _NeumorphicPillButtonState();
}

class _NeumorphicPillButtonState extends State<NeumorphicPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
  final base = widget.color ?? const Color(0xFFEFEFEF); // allow override
  // derive dynamic shadow intensity based on luminance
  final lum = base.computeLuminance();
  final darkShadow = Colors.black.withValues(alpha: lum > 0.7 ? 0.18 : 0.30);
  final lightShadow = Colors.white.withValues(alpha: lum > 0.5 ? 0.55 : 0.35);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _pressed
              ? [
                  BoxShadow(
          offset: const Offset(2, 2),
          blurRadius: 6,
          color: darkShadow,
                  ),
                  BoxShadow(
          offset: const Offset(-2, -2),
          blurRadius: 6,
          color: lightShadow,
                  ),
                ]
              : [
                  BoxShadow(
          offset: const Offset(10, 10),
          blurRadius: 24,
          color: darkShadow,
                  ),
                  BoxShadow(
          offset: const Offset(-10, -10),
          blurRadius: 24,
          color: lightShadow,
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C3C3C),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class NeumorphicPanel extends StatelessWidget {
  final Widget child;
  const NeumorphicPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFEFEFEF);
    return Container(
      width: 280,
      height: 260,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(offset: Offset(16, 16), blurRadius: 36, color: Color(0x1A000000)),
          BoxShadow(offset: Offset(-16, -16), blurRadius: 36, color: Color(0xE6FFFFFF)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 98, 93, 93),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(offset: Offset(8, 8), blurRadius: 18, color: Color(0x14000000)),
            BoxShadow(offset: Offset(-8, -8), blurRadius: 18, color: Color(0xF2FFFFFF)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // warm center glow behind the lamp
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.05),
                    radius: 0.65,
                    colors: [Color(0xCCFFF3C4), Color(0x00FFFFFF)],
                  ),
                ),
              ),
              // 3D model fills the panel
              Positioned.fill(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class ControlCard extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget control;

  const ControlCard({
    super.key,
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
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
                  gradient: RadialGradient(colors: iconGradient),
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient.first.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
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
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ThemeManager.I.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: subtitleColor ?? ThemeManager.I.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          control,
        ],
      ),
    );
  }
}