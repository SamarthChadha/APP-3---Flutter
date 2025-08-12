import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
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
                onTap: () => setState(() => _isOn = !_isOn),
              ),
              const SizedBox(height: 28),
              // Brightness label
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
                        onChanged: (v) => setState(() => _brightness = v),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              // Color Temperature label
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
                        onChanged: (v) => setState(() => _tempK = v),
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
  const NeumorphicPillButton({super.key, required this.label, required this.onTap});

  @override
  State<NeumorphicPillButton> createState() => _NeumorphicPillButtonState();
}

class _NeumorphicPillButtonState extends State<NeumorphicPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFEFEFEF); // soft surface color matching the reference
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
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  BoxShadow(
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ]
              : [
                  BoxShadow(
                    offset: const Offset(10, 10),
                    blurRadius: 24,
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                  BoxShadow(
                    offset: const Offset(-10, -10),
                    blurRadius: 24,
                    color: Colors.white.withValues(alpha: 0.5),
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