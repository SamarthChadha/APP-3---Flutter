import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:circadian_light/core/esp_connection.dart';
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

  @override
  void dispose() {
    _brightTimer?.cancel();
    _tempTimer?.cancel();
    super.dispose();
  }

  int _mapBrightnessTo15(double v) {
    // Round to nearest 0..15; ensure at least 1 when on and >0 visually
    final val = (v.clamp(0.0, 1.0) * 15).round();
    return val.clamp(0, 15);
  }

  int _modeFromTemp(double k) {
    // Simple split: <=3000 warm (0), >=5000 white (1), else both (2)
    if (k <= 3000) return 0; // MODE_WARM
    if (k >= 5000) return 1; // MODE_WHITE
    return 2; // MODE_BOTH
  }
  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFEFEFEF);
    return Scaffold(
      backgroundColor: Colors.grey,
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
                          style: const TextStyle(color: Colors.white70),
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
              NeumorphicPillButton(
                label: _isOn ? 'Turn Off' : 'Turn On',
                // Swap colors: when ON use light grey base, when OFF show yellow highlight
                color: _isOn ? const Color(0xFFEFEFEF) : const Color(0xFFFFC049),
                onTap: () {
                  setState(() => _isOn = !_isOn);
                  EspConnection.I.setOn(_isOn);
                },
              ),
              const SizedBox(height: 28),
              // Color Temperature label (moved above Brightness)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color Temperature',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3C3C),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Color Temperature slider 
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
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
                            offset: const Offset(6, 6),
                            blurRadius: 18,
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          BoxShadow(
                            offset: const Offset(-6, -6),
                            blurRadius: 18,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 18,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: base,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
                      ),
                      child: Slider(
                        min: 1800,
                        max: 6500,
                        value: _tempK,
                        onChanged: (v) {
                          setState(() => _tempK = v);
                          _tempTimer?.cancel();
                          _tempTimer = Timer(const Duration(milliseconds: 80), () {
                            EspConnection.I.setMode(_modeFromTemp(_tempK));
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              // Brightness label (moved below Color Temperature)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Brightness',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3C3C),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Brightness slider (neumorphic track)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(6, 6),
                            blurRadius: 18,
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                          BoxShadow(
                            offset: const Offset(-6, -6),
                            blurRadius: 18,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 18,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: base,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
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
                          });
                        },
                      ),
                    ),
                  ],
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