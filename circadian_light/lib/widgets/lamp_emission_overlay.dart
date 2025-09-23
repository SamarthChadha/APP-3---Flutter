import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LampEmissionOverlay extends StatefulWidget {
  final double brightness; // 0.0 to 1.0
  final double temperature; // 2700 to 6500 Kelvin
  final bool isOn;

  const LampEmissionOverlay({
    super.key,
    required this.brightness,
    required this.temperature,
    required this.isOn,
  });

  @override
  State<LampEmissionOverlay> createState() => _LampEmissionOverlayState();
}

class _LampEmissionOverlayState extends State<LampEmissionOverlay>
    with TickerProviderStateMixin {
  ui.FragmentProgram? _program;
  ui.Image? _texture;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadShader();
    _loadTexture();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('assets/shaders/lamp_shader.frag');
      setState(() {
        _program = program;
      });
    } catch (e) {
      debugPrint('Error loading shader: $e');
    }
  }

  Future<void> _loadTexture() async {
    try {
      final data = await rootBundle.load('assets/textures/Small_Lamp_UVMap_Textured.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _texture = frame.image;
      });
    } catch (e) {
      debugPrint('Error loading texture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null || _texture == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(280, 260),
          painter: LampEmissionPainter(
            program: _program!,
            texture: _texture!,
            brightness: widget.isOn ? widget.brightness : 0.0,
            temperature: widget.temperature,
            time: _animationController.value * 2 * 3.14159,
          ),
        );
      },
    );
  }
}

class LampEmissionPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image texture;
  final double brightness;
  final double temperature;
  final double time;

  LampEmissionPainter({
    required this.program,
    required this.texture,
    required this.brightness,
    required this.temperature,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Set uniforms
    shader.setFloat(0, size.width);  // uSize.x
    shader.setFloat(1, size.height); // uSize.y
    shader.setFloat(2, time);        // uTime
    shader.setFloat(3, brightness);  // uBrightness
    shader.setFloat(4, temperature); // uTemperature
    shader.setImageSampler(0, texture); // uTexture

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.screen; // Additive blending for glow effect

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(LampEmissionPainter oldDelegate) {
    return oldDelegate.brightness != brightness ||
        oldDelegate.temperature != temperature ||
        oldDelegate.time != time;
  }
}