import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
// import 'package:flutter_gl/flutter_gl.dart';
// import 'package:flutter_3d_controller/'

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOn = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 55),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // const Text('Hi This is home Screen'),
              SizedBox(
                height: 250,
                child:
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationX(3.1416),
                    child: const Flutter3DViewer(src: 'assets/models/Textured_Lamp_Small.glb')
                    )
              ),
              const SizedBox(height: 24),
              NeumorphicPillButton(
                label: _isOn ? 'Turn Off' : 'Turn On',
                onTap: () => setState(() => _isOn = !_isOn),
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