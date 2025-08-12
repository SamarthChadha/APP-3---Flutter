import 'package:flutter/material.dart';

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

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _routines = <Routine>[];

  String _formatTime(BuildContext context, TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  void _openAddRoutineSheet() async {
    final theme = Theme.of(context);

    TimeOfDay start = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 22, minute: 0);
    Color selectedColor = Colors.amber;
    double brightness = 70;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
              Future<void> pickStart() async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: start,
                );
                if (picked != null) setSheetState(() => start = picked);
              }

              Future<void> pickEnd() async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: end,
                );
                if (picked != null) setSheetState(() => end = picked);
              }

              final colors = [Colors.amber, Colors.white, Colors.blue, Colors.pink];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Create Routine'),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Routine start time'),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: pickStart,
                    icon: const Icon(Icons.schedule),
                    label: Text(_formatTime(context, start)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Routine end time'),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: pickEnd,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_formatTime(context, end)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Light color'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final c in colors)
                        GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = c),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor,
                                width: selectedColor == c ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Light brightness'),
                      Text('${brightness.round()}%'),
                    ],
                  ),
                  Slider(
                    value: brightness,
                    min: 0,
                    max: 100,
                    onChanged: (v) => setSheetState(() => brightness = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
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