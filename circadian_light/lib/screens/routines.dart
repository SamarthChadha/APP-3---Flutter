import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../core/sunrise_sunset_manager.dart';


class Routine {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final double brightness;
  final double temperature; // store kelvin for editing
  bool enabled;

  Routine({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.brightness,
    required this.temperature,
    this.enabled = true,
  });

  Routine copyWith({
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    double? brightness,
    double? temperature,
    bool? enabled,
  }) => Routine(
        name: name ?? this.name,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        color: color ?? this.color,
        brightness: brightness ?? this.brightness,
        temperature: temperature ?? this.temperature,
        enabled: enabled ?? this.enabled,
      );
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
  final nameCtrl = TextEditingController(text: 'Routine ${_routines.length + 1}');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
  // Use app grey background for consistency with rest of app
  backgroundColor: const Color.fromARGB(255, 208, 206, 206),
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
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Routine name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                        final name = nameCtrl.text.trim().isEmpty
                            ? 'Routine ${_routines.length + 1}'
                            : nameCtrl.text.trim();
                        setState(() => _routines.add(Routine(
                              name: name,
                              startTime: start,
                              endTime: end,
                              color: selectedColor,
                              brightness: brightness,
                              temperature: temperature,
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

  void _openEditRoutineSheet(int index, Routine routine) {
    TimeOfDay start = routine.startTime;
    TimeOfDay end = routine.endTime;
    double temperature = routine.temperature;
    double brightness = routine.brightness;
    Color selectedColor = routine.color;
    final nameCtrl = TextEditingController(text: routine.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color.fromARGB(255, 208, 206, 206),
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

              Future<void> pickStart() async {
                TimeOfDay temp = start;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => _timeSheet(
                    initial: start,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () { setSheetState(() => start = temp); Navigator.pop(context);},
                  ),
                );
              }
              Future<void> pickEnd() async {
                TimeOfDay temp = end;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => _timeSheet(
                    initial: end,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () { setSheetState(() => end = temp); Navigator.pop(context);},
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Edit Routine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Routine name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(onPressed: pickStart, icon: const Icon(Icons.schedule), label: Text(_formatTime(context, start))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(onPressed: pickEnd, icon: const Icon(Icons.schedule_outlined), label: Text(_formatTime(context, end))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Color Temperature', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _NeumorphicSlider(
                      gradient: const LinearGradient(colors: [Color(0xFFFFC477), Color(0xFFBFD7FF)]),
                      value: temperature,
                      min: 2700,
                      max: 6500,
                      onChanged: (v) => setSheetState(() { temperature = v; selectedColor = _colorFromTemperature(v); }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Brightness', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _NeumorphicSlider(
                      solidColor: base,
                      value: brightness,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setSheetState(() => brightness = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC049),
                        foregroundColor: const Color(0xFF3C3C3C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () {
                        setState(() => _routines[index] = routine.copyWith(
                              name: nameCtrl.text.trim().isEmpty ? routine.name : nameCtrl.text.trim(),
                              startTime: start,
                              endTime: end,
                              color: selectedColor,
                              brightness: brightness,
                              temperature: temperature,
                            ));
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _timeSheet({
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
                  CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 16), onPressed: onCancel, child: const Text('Cancel')),
                  CupertinoButton(padding: const EdgeInsets.symmetric(horizontal: 16), onPressed: onSave, child: const Text('Save')),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                initialDateTime: DateTime(0,1,1,initial.hour, initial.minute),
                onDateTimeChanged: (v) => onChanged(TimeOfDay(hour: v.hour, minute: v.minute)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomClearance = kBottomNavigationBarHeight + 24;
    final bool sunriseSunsetEnabled = SunriseSunsetManager.I.isEnabled;

    Widget content;
    
    if (sunriseSunsetEnabled) {
      // Show sunrise/sunset status when enabled
      content = Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomClearance + 16),
        child: Column(
          children: [
            // Neumorphic style status card matching routine cards
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                children: [
                  // Icon and title row
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
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
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sunrise & Sunset Sync Active',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status text
                  Text(
                    SunriseSunsetManager.I.getCurrentStatus(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Times container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Sunrise',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SunriseSunsetManager.I.sunriseTime.format(context),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Sunset',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SunriseSunsetManager.I.sunsetTime.format(context),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'All manual routines are disabled while sunrise/sunset sync is active. '
                    'You can disable this feature in Settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quick Test Mode Card
            Container(
              width: double.infinity,
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
                            colors: [Color(0xFF673AB7), Color(0xFF9C27B0)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.45),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.speed,
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
                              'Quick Test Mode',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F2F2F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SunriseSunsetManager.I.testModeEnabled 
                                ? 'Fast transitions for testing (2 min)'
                                : 'Normal timing (15 min transitions)',
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
                        value: SunriseSunsetManager.I.testModeEnabled,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              SunriseSunsetManager.I.enableTestMode();
                            } else {
                              SunriseSunsetManager.I.disableTestMode();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (SunriseSunsetManager.I.testModeEnabled) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
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
                          const Text(
                            'Test Full Cycle',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF2F2F2F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Complete cycle: 3min sunrise → 5min wait → 3min sunset (~11 minutes total)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
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
                                onTap: SunriseSunsetManager.I.isTestSequenceRunning ? null : () async {
                                  await SunriseSunsetManager.I.startTestCycle();
                                  if (mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                    child: Text(
                                      SunriseSunsetManager.I.isTestSequenceRunning ? 'Running Test Cycle...' : 'Start Test Cycle',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (SunriseSunsetManager.I.isTestSequenceRunning) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFFEF5350),
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
                                  onTap: () {
                                    SunriseSunsetManager.I.stopTestSequence();
                                    setState(() {});
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text(
                                        'Stop Test',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_routines.isNotEmpty) ...[
              const Text(
                'Disabled Routines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _routines.length,
                  itemBuilder: (context, i) {
                    final r = _routines[i];
                    return _RoutineCard(
                      routine: r.copyWith(enabled: false), // Force disabled appearance
                      onChanged: (val) {}, // No-op when sunrise/sunset is active
                      onTap: null, // Disable editing
                      isDisabledBySunriseSync: true,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Normal routines view
      content = _routines.isEmpty
          ? const Center(child: Text('No routines yet'))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomClearance + 16),
              itemCount: _routines.length,
              itemBuilder: (context, i) {
                final r = _routines[i];
                return _RoutineCard(
                  routine: r,
                  onChanged: (val) => setState(() => r.enabled = val),
                  onTap: () => _openEditRoutineSheet(i, r),
                );
              },
            );
    }

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
        actions: sunriseSunsetEnabled ? [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sunrise/Sunset Sync'),
                  content: const Text(
                    'Manual routines are disabled while sunrise/sunset sync is active. '
                    'The lamp will automatically adjust based on the time of day.\n\n'
                    'To use manual routines again, disable sunrise/sunset sync in Settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ] : null,
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          if (!sunriseSunsetEnabled)
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

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final bool isDisabledBySunriseSync;
  
  const _RoutineCard({
    required this.routine, 
    required this.onChanged, 
    this.onTap,
    this.isDisabledBySunriseSync = false,
  });

  String _formatTime(BuildContext context, TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  @override
  Widget build(BuildContext context) {
    final timeRange = '${_formatTime(context, routine.startTime)} – ${_formatTime(context, routine.endTime)}';
    final isEffectivelyDisabled = !routine.enabled || isDisabledBySunriseSync;
    
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEffectivelyDisabled
              ? [const Color(0xFFE5E5E5), const Color(0xFFD4D4D4)]
              : [const Color(0xFFFDFDFD), const Color(0xFFE3E3E3)],
        ),
        boxShadow: const [
          BoxShadow(offset: Offset(6, 6), blurRadius: 18, color: Color(0x1F000000)),
          BoxShadow(offset: Offset(-6, -6), blurRadius: 18, color: Color(0x88FFFFFF)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  routine.color.withValues(alpha: isEffectivelyDisabled ? 0.3 : 0.9), 
                  routine.color.withValues(alpha: isEffectivelyDisabled ? 0.1 : 0.25)
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: routine.color.withValues(alpha: isEffectivelyDisabled ? 0.15 : 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2F2F2F).withValues(alpha: isEffectivelyDisabled ? 0.4 : 1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: const Color(0xFF3C3C3C).withValues(alpha: isEffectivelyDisabled ? 0.3 : 0.85),
                  ),
                ),
                if (isDisabledBySunriseSync) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Disabled by Sunrise/Sunset Sync',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Show switch but disable interaction when sunrise/sunset is active
          IgnorePointer(
            ignoring: isDisabledBySunriseSync,
            child: Switch(
              value: routine.enabled && !isDisabledBySunriseSync,
              onChanged: isDisabledBySunriseSync ? null : onChanged,
            ),
          ),
        ],
      ),
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: isDisabledBySunriseSync ? null : onTap,
          child: card,
        ),
      ),
    );
  }
}