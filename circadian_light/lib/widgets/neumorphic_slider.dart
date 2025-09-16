import 'package:flutter/material.dart';

class NeumorphicSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final LinearGradient? gradient; // if null solidColor used
  final Color? solidColor; // fallback single color (default base)

  const NeumorphicSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.gradient,
    this.solidColor,
  });

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFFEFEFEF);
    final trackDecoration = BoxDecoration(
      color: gradient == null ? (solidColor ?? base) : null,
      gradient: gradient,
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(height: 18, decoration: trackDecoration),
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
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
