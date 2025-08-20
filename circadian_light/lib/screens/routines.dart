import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;


class Routine {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final double brightness;

  const Routine({
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.brightness,
  });
}

// Custom gradient/white slider track with soft shadow and glow
class GradientRectSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  final LinearGradient gradient;
  final double trackBorderRadius;
  final double shadowSigma;
  const GradientRectSliderTrackShape({
    required this.gradient,
    this.trackBorderRadius = 20,
    this.shadowSigma = 12,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    Offset? secondaryOffset,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    ).shift(offset);

    final RRect rrect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackBorderRadius),
    );

    // Soft shadow below
    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadowSigma);
    context.canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadow);

    // Gentle top glow
    final Paint glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadowSigma / 2);
    context.canvas.drawRRect(rrect.shift(const Offset(0, -1)), glow);

    // Gradient/solid track fill
    final Paint fill = Paint()..shader = gradient.createShader(trackRect);
    context.canvas.drawRRect(rrect, fill);

    // Subtle border to improve contrast on light backgrounds
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.08);
    context.canvas.drawRRect(rrect, border);
  }
}

class NeumorphicThumbShape extends SliderComponentShape {
  final double radius;
  const NeumorphicThumbShape({this.radius = 16});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // Shadow
    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    context.canvas.drawCircle(center.translate(0, 2), radius, shadow);

    // Thumb fill
    final Paint fill = Paint()..color = Colors.white;
    context.canvas.drawCircle(center, radius, fill);

    // Thin ring
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.10);
    context.canvas.drawCircle(center, radius, ring);
  }
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

// Reusable neumorphic slider matching design used on home screen.
class _NeumorphicSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final LinearGradient? gradient; // if null solidColor used
  final Color? solidColor; // fallback single color (default base)
  const _NeumorphicSlider({
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

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _routines = <Routine>[];

  Color _colorFromTemperature(double kelvin) {
    double t = kelvin / 100.0;
    double r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.4708025861 * math.log(t) - 161.1195681661;
      b = t <= 19 ? 0 : 138.5177312231 * math.log(t - 10) - 305.0447927307;
    } else {
      r = 329.698727446 * math.pow(t - 60, -0.1332047592);
      g = 288.1221695283 * math.pow(t - 60, -0.0755148492);
      b = 255;
    }
    int r8 = r.isNaN ? 0 : r.clamp(0, 255).round();
    int g8 = g.isNaN ? 0 : g.clamp(0, 255).round();
    int b8 = b.isNaN ? 0 : b.clamp(0, 255).round();
    return Color.fromARGB(255, r8, g8, b8);
  }

  String _formatTime(BuildContext context, TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  void _openAddRoutineSheet() async {
    TimeOfDay start = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 22, minute: 0);
    double temperature = 4000;
    Color selectedColor = _colorFromTemperature(temperature); 
    double brightness = 70;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
  // Match home screen base color for consistent neumorphic look
  backgroundColor: const Color(0xFFEFEFEF),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
      const base = Color(0xFFEFEFEF);

              Widget buildCupertinoTimePickerSheet(
                BuildContext context, {
                required TimeOfDay initial,
                required ValueChanged<TimeOfDay> onChanged,
                required VoidCallback onCancel,
                required VoidCallback onSave,
              }) {
                return SafeArea(
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                onPressed: onCancel,
                                child: const Text('Cancel'),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                onPressed: onSave,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            minuteInterval: 1,
                            use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                            initialDateTime: DateTime(0, 1, 1, initial.hour, initial.minute),
                            onDateTimeChanged: (DateTime v) {
                              onChanged(TimeOfDay(hour: v.hour, minute: v.minute));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Future<void> pickStart() async {
                TimeOfDay temp = start;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) {
                    return buildCupertinoTimePickerSheet(
                      context,
                      initial: start,
                      onChanged: (t) => temp = t,
                      onCancel: () => Navigator.of(context).pop(),
                      onSave: () {
                        setSheetState(() => start = temp);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              }

              Future<void> pickEnd() async {
                TimeOfDay temp = end;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) {
                    return buildCupertinoTimePickerSheet(
                      context,
                      initial: end,
                      onChanged: (t) => temp = t,
                      onCancel: () => Navigator.of(context).pop(),
                      onSave: () {
                        setSheetState(() => end = temp);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create Routine',
                        style:TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        )
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Routine start time'),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: pickStart,
                              icon: const Icon(Icons.schedule),
                              label: Text(_formatTime(context, start)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Routine end time'),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: pickEnd,
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(_formatTime(context, end)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Color Temperature',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3C3C),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NeumorphicSlider(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFFFC477), // warm
                        Color(0xFFBFD7FF), // cool
                      ],
                    ),
                    value: temperature,
                    min: 2700,
                    max: 6500,
                    onChanged: (v) => setSheetState(() {
                      temperature = v;
                      selectedColor = _colorFromTemperature(temperature);
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Brightness',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3C3C),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NeumorphicSlider(
                    solidColor: base,
                    value: brightness,
                    min: 0,
                    max: 100,
                    onChanged: (v) => setSheetState(() => brightness = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC049),
                        foregroundColor: const Color(0xFF3C3C3C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: () {
                        setState(() => _routines.add(Routine(
                              startTime: start,
                              endTime: end,
                              color: selectedColor,
                              brightness: brightness,
                            )));
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance = kBottomNavigationBarHeight + 24;

    final content = _routines.isEmpty
        ? const Center(child: Text('No routines yet'))
        : ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomClearance + 16),
            itemCount: _routines.length,
            itemBuilder: (context, i) {
              final r = _routines[i];
              return ListTile(
                leading: CircleAvatar(backgroundColor: r.color),
                title: Text(
                    '${_formatTime(context, r.startTime)} — ${_formatTime(context, r.endTime)}'),
                subtitle: Text('Brightness: ${r.brightness.round()}%'),
                trailing: const Icon(Icons.chevron_right),
              );
            },
          );

    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        backgroundColor: Colors.grey,
        title: const Text(
          'Routines',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            left: 40,
            right: 40,
            bottom: bottomClearance + 24,
            child: Material(
              color: Colors.white,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openAddRoutineSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Add Routine',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF3D3D3D),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}