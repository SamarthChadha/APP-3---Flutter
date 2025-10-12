import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/sunrise_sunset_manager.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../core/routine_core.dart';
import '../widgets/neumorphic_slider.dart';
import '../widgets/time_picker_sheet.dart';
import '../widgets/alarm_duration_selector.dart';
import '../widgets/routine_card.dart';
import '../widgets/alarm_card.dart';
import '../core/theme_manager.dart';

/// Screen for managing circadian lighting routines and wake-up alarms.
///
/// This screen provides a interface for users to create, edit, and manage
/// automated lighting schedules (routines) and gradual wake-up alarms.
///
/// Key features:
/// - Create/edit/delete lighting routines with custom time ranges, colors, and brightness
/// - Create/edit/delete wake-up alarms with configurable ramp-up durations
/// - Automatic sunrise/sunset sync that disables manual routines when active
/// - Undo functionality for deleted items
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

/// State management for RoutinesScreen.
///
/// Handles all business logic for routine and alarm CRUD operations,
/// including undo functionality, sunrise/sunset sync integration,
/// and modal sheet presentations for editing items.
class _RoutinesScreenState extends State<RoutinesScreen> {
  /// Core controller for routine and alarm data operations.
  late final RoutineCore _core;

  /// Stores recently deleted routine for undo functionality.
  Routine? _recentlyDeletedRoutine;

  /// Stores recently deleted alarm for undo functionality.
  Alarm? _recentlyDeletedAlarm;

  @override
  void initState() {
    super.initState();
    _core = RoutineCore();
    _core.addListener(() {
      if (mounted) setState(() {});
    });
    // Fire and forget initialization
    _core.init();
  }

  @override
  void dispose() {
    _core.dispose();
    super.dispose();
  }

  /// Saves a routine to persistent storage with error handling.
  ///
  /// Attempts to save the routine via RoutineCore and shows appropriate
  /// snackbar messages for success or duplicate name errors.
  Future<void> _saveRoutine(Routine routine) async {
    try {
      await _core.saveRoutine(routine);
    } on DuplicateRoutineException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving routine: $e')));
      }
    }
  }

  /// Deletes a routine with undo functionality.
  ///
  /// Removes the routine from storage, stores it for potential undo,
  /// and shows a snackbar with undo option that expires after 4 seconds.
  Future<void> _deleteRoutine(int id) async {
    try {
      // Find the routine before deleting
      final routineToDelete = _core.routines.firstWhere((r) => r.id == id);
      _recentlyDeletedRoutine = routineToDelete;

      // Delete immediately
      await _core.deleteRoutine(id);

      if (mounted) {
        // Show undo snackbar
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text('${routineToDelete.name} was deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    if (_recentlyDeletedRoutine != null) {
                      try {
                        await _saveRoutine(
                          _recentlyDeletedRoutine!.copyWith(id: null),
                        );
                        _recentlyDeletedRoutine = null;
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error restoring routine: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                duration: const Duration(seconds: 4),
              ),
            )
            .closed
            .then((_) {
              // Clear the stored routine when snackbar is dismissed
              _recentlyDeletedRoutine = null;
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting routine: $e')));
      }
    }
  }

  /// Saves an alarm to persistent storage with error handling.
  ///
  /// Attempts to save the alarm via RoutineCore and shows appropriate
  /// snackbar messages for success or duplicate name errors.
  Future<void> _saveAlarm(Alarm alarm) async {
    try {
      await _core.saveAlarm(alarm);
    } on DuplicateAlarmException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving alarm: $e')));
      }
    }
  }

  /// Deletes an alarm with undo functionality.
  ///
  /// Removes the alarm from storage, stores it for potential undo,
  /// and shows a snackbar with undo option that expires after 4 seconds.
  Future<void> _deleteAlarm(int id) async {
    try {
      // Find the alarm before deleting
      final alarmToDelete = _core.alarms.firstWhere((a) => a.id == id);
      _recentlyDeletedAlarm = alarmToDelete;

      // Delete immediately
      await _core.deleteAlarm(id);

      if (mounted) {
        // Show undo snackbar
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text('${alarmToDelete.name} was deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    if (_recentlyDeletedAlarm != null) {
                      try {
                        await _saveAlarm(
                          _recentlyDeletedAlarm!.copyWith(id: null),
                        );
                        _recentlyDeletedAlarm = null;
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error restoring alarm: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                duration: const Duration(seconds: 4),
              ),
            )
            .closed
            .then((_) {
              // Clear the stored alarm when snackbar is dismissed
              _recentlyDeletedAlarm = null;
            });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting alarm: $e')));
      }
    }
  }

  /// Formats a TimeOfDay for display using Material localization.
  String _formatTime(BuildContext context, TimeOfDay t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(t);

  /// Opens a modal bottom sheet for creating a new routine.
  ///
  /// Presents a form with controls for routine name, start/end times,
  /// color temperature, and brightness. Uses StatefulBuilder to manage
  /// local state within the modal sheet.
  void _openAddRoutineSheet() async {
    TimeOfDay start = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 22, minute: 0);
    double temperature = 4000;
    Color selectedColor = RoutineCore.colorFromTemperature(temperature);
    double brightness = 70;
    final nameCtrl = TextEditingController(
      text: 'Routine ${_core.routines.length + 1}',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ThemeManager.I.sheetBackgroundColor,
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
              // Inline time picker replaced with reusable TimePickerSheet

              Future<void> pickStart() async {
                TimeOfDay temp = start;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) {
                    return TimePickerSheet(
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
                    return TimePickerSheet(
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
                      Text(
                        'Create Routine',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: ThemeManager.I.primaryTextColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: ThemeManager.I.primaryTextColor,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Routine name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Routine start time',
                              style: TextStyle(
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
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
                            Text(
                              'Routine end time',
                              style: TextStyle(
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
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
                  Text(
                    'Color Temperature',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: ThemeManager.I.primaryTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${temperature.round()}K - ${temperature <= 3000
                        ? 'Warm'
                        : temperature >= 5000
                        ? 'Cool'
                        : 'Mixed'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: ThemeManager.I.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  NeumorphicSlider(
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
                      selectedColor = RoutineCore.colorFromTemperature(
                        temperature,
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Brightness',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: ThemeManager.I.primaryTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${brightness.round()}% intensity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: ThemeManager.I.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  NeumorphicSlider(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF424242), // dark/dim
                        Color(0xFFFFFFFF), // bright/white
                      ],
                    ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim().isEmpty
                            ? 'Routine ${_core.routines.length + 1}'
                            : nameCtrl.text.trim();
                        final newRoutine = Routine(
                          name: name,
                          startTime: start,
                          endTime: end,
                          color: selectedColor,
                          brightness: brightness,
                          temperature: temperature,
                        );
                        Navigator.of(ctx).pop();
                        await _saveRoutine(newRoutine);
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

  /// Opens a modal bottom sheet for editing an existing routine.
  ///
  /// Pre-fills the form with the routine's current values and allows
  /// modification of all properties. Saves changes back to the routine.
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
      backgroundColor: ThemeManager.I.sheetBackgroundColor,
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
                TimeOfDay temp = start;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => TimePickerSheet(
                    initial: start,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () {
                      setSheetState(() => start = temp);
                      Navigator.pop(context);
                    },
                  ),
                );
              }

              Future<void> pickEnd() async {
                TimeOfDay temp = end;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => TimePickerSheet(
                    initial: end,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () {
                      setSheetState(() => end = temp);
                      Navigator.pop(context);
                    },
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
                        Text(
                          'Edit Routine',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Routine name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
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
                              Text(
                                'Start',
                                style: TextStyle(
                                  color: ThemeManager.I.primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                              Text(
                                'End',
                                style: TextStyle(
                                  color: ThemeManager.I.primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
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
                    const SizedBox(height: 16),
                    Text(
                      'Color Temperature',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ThemeManager.I.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${temperature.round()}K - ${temperature <= 3000
                          ? 'Warm'
                          : temperature >= 5000
                          ? 'Cool'
                          : 'Mixed'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: ThemeManager.I.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicSlider(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC477), Color(0xFFBFD7FF)],
                      ),
                      value: temperature,
                      min: 2700,
                      max: 6500,
                      onChanged: (v) => setSheetState(() {
                        temperature = v;
                        selectedColor = RoutineCore.colorFromTemperature(v);
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Brightness',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ThemeManager.I.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${brightness.round()}% intensity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: ThemeManager.I.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    NeumorphicSlider(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF424242), // dark/dim
                          Color(0xFFFFFFFF), // bright/white
                        ],
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () async {
                        final updatedRoutine = routine.copyWith(
                          name: nameCtrl.text.trim().isEmpty
                              ? routine.name
                              : nameCtrl.text.trim(),
                          startTime: start,
                          endTime: end,
                          color: selectedColor,
                          brightness: brightness,
                          temperature: temperature,
                        );
                        Navigator.pop(ctx);
                        await _saveRoutine(updatedRoutine);
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

  // Time sheet moved to reusable widget (TimePickerSheet)

  /// Opens a modal bottom sheet for editing an existing alarm.
  ///
  /// Pre-fills the form with the alarm's current wake-up time and duration,
  /// allowing modification of these properties before saving changes.
  void _openEditAlarmSheet(int index, Alarm alarm) {
    TimeOfDay wakeUpTime = alarm.wakeUpTime;
    int durationMinutes = alarm.durationMinutes;
    final nameCtrl = TextEditingController(text: alarm.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ThemeManager.I.sheetBackgroundColor,
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
              Future<void> pickWakeUpTime() async {
                TimeOfDay temp = wakeUpTime;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => TimePickerSheet(
                    initial: wakeUpTime,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () {
                      setSheetState(() => wakeUpTime = temp);
                      Navigator.pop(context);
                    },
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
                        Text(
                          'Edit Alarm',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Alarm name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wake-up time',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: pickWakeUpTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(wakeUpTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ramp-up duration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeManager.I.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AlarmDurationSelector(
                      value: durationMinutes,
                      onChanged: (v) =>
                          setSheetState(() => durationMinutes = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC049),
                        foregroundColor: const Color(0xFF3C3C3C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () async {
                        final updatedAlarm = alarm.copyWith(
                          name: nameCtrl.text.trim().isEmpty
                              ? alarm.name
                              : nameCtrl.text.trim(),
                          wakeUpTime: wakeUpTime,
                          durationMinutes: durationMinutes,
                        );
                        Navigator.pop(ctx);
                        await _saveAlarm(updatedAlarm);
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

  /// Opens a modal bottom sheet for creating a new wake-up alarm.
  ///
  /// Presents a form with controls for alarm name, wake-up time, and ramp-up
  /// duration. Shows a preview of how the gradual lighting will work.
  /// Uses StatefulBuilder to manage local state within the modal sheet.
  void _openAddAlarmSheet() async {
    TimeOfDay wakeUpTime = const TimeOfDay(hour: 6, minute: 0);
    int durationMinutes = 30; // Default to 30 minutes
    final nameCtrl = TextEditingController(
      text: 'Alarm ${_core.alarms.length + 1}',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ThemeManager.I.sheetBackgroundColor,
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
              Future<void> pickWakeUpTime() async {
                TimeOfDay temp = wakeUpTime;
                await showCupertinoModalPopup<void>(
                  context: context,
                  builder: (_) => TimePickerSheet(
                    initial: wakeUpTime,
                    onChanged: (t) => temp = t,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: () {
                      setSheetState(() => wakeUpTime = temp);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              }

              // Calculate start time based on wake up time and duration
              final startTime = RoutineCore.calculateAlarmStartTime(
                wakeUpTime,
                durationMinutes,
              );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Alarm',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Alarm name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wake-up time',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeManager.I.primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: pickWakeUpTime,
                            icon: const Icon(Icons.schedule),
                            label: Text(_formatTime(context, wakeUpTime)),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeManager.I.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: durationMinutes == 10
                                ? const Color(0xFFFFC049)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setSheetState(() => durationMinutes = 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: durationMinutes == 10
                                        ? const Color(0xFFFFC049)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (durationMinutes == 10) ...[
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Color(0xFF3C3C3C),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '10m',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: durationMinutes == 10
                                            ? const Color(0xFF3C3C3C)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            color: durationMinutes == 20
                                ? const Color(0xFFFFC049)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setSheetState(() => durationMinutes = 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: durationMinutes == 20
                                        ? const Color(0xFFFFC049)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (durationMinutes == 20) ...[
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Color(0xFF3C3C3C),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '20m',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: durationMinutes == 20
                                            ? const Color(0xFF3C3C3C)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            color: durationMinutes == 30
                                ? const Color(0xFFFFC049)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setSheetState(() => durationMinutes = 30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: durationMinutes == 30
                                        ? const Color(0xFFFFC049)
                                        : Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (durationMinutes == 30) ...[
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Color(0xFF3C3C3C),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '30m',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: durationMinutes == 30
                                            ? const Color(0xFF3C3C3C)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your lamp will gradually brighten from ${_formatTime(context, startTime)} to ${_formatTime(context, wakeUpTime)}, reaching full brightness at wake-up time.',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC049),
                        foregroundColor: const Color(0xFF3C3C3C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () async {
                        final alarm = Alarm(
                          name: nameCtrl.text.trim().isEmpty
                              ? 'Alarm ${_core.alarms.length + 1}'
                              : nameCtrl.text.trim(),
                          wakeUpTime: wakeUpTime,
                          durationMinutes: durationMinutes,
                        );
                        Navigator.pop(ctx);
                        await _saveAlarm(alarm);
                      },
                      child: const Text('Create Alarm'),
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

  @override
  Widget build(BuildContext context) {
    final bottomClearance = kBottomNavigationBarHeight + 24;
    final bool sunriseSunsetEnabled = SunriseSunsetManager.I.isEnabled;

    Widget content;

    /// Builds the UI content based on sunrise/sunset sync status.
    ///
    /// When sunrise/sunset sync is enabled, shows a status card with current
    /// times and disables manual routine controls. When disabled, shows the
    /// normal list of routines and alarms with full CRUD functionality.
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ThemeManager.I.neumorphicGradient,
                ),
                boxShadow: ThemeManager.I.neumorphicShadows,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sunrise & Sunset Sync Active',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: ThemeManager.I.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Times container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ThemeManager.I.infoBackgroundColor,
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
                            Text(
                              'Sunrise',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: ThemeManager.I.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SunriseSunsetManager.I.sunriseTime.format(
                                context,
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              'Sunset',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: ThemeManager.I.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              SunriseSunsetManager.I.sunsetTime.format(context),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ThemeManager.I.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All manual routines are disabled while sunrise/sunset sync is active. '
                    'You can disable this feature in Settings.',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeManager.I.tertiaryTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_core.routines.isNotEmpty || _core.alarms.isNotEmpty) ...[
              Text(
                'Disabled Routines & Alarms',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeManager.I.tertiaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    // Show disabled routines
                    ..._core.routines.map(
                      (r) => RoutineCard(
                        routine: r.copyWith(
                          enabled: false,
                        ), // Force disabled appearance
                        onChanged:
                            (val) {}, // No-op when sunrise/sunset is active
                        onTap: null, // Disable editing
                        onDelete:
                            null, // Disable deletion when sunrise/sunset is active
                        isDisabledBySunriseSync: true,
                      ),
                    ),
                    // Show disabled alarms
                    ..._core.alarms.map(
                      (a) => AlarmCard(
                        alarm: a.copyWith(
                          enabled: false,
                        ), // Force disabled appearance
                        onChanged:
                            (val) {}, // No-op when sunrise/sunset is active
                        onTap: null, // Disable editing
                        onDelete:
                            null, // Disable deletion when sunrise/sunset is active
                        isDisabledBySunriseSync: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Normal routines and alarms view
      final allItems = <Widget>[];

      // Add routines
      for (int i = 0; i < _core.routines.length; i++) {
        final r = _core.routines[i];
        allItems.add(
          RoutineCard(
            routine: r,
            onChanged: (val) async {
              final updatedRoutine = r.copyWith(enabled: val);
              await _saveRoutine(updatedRoutine);
            },
            onTap: () => _openEditRoutineSheet(i, r),
            onDelete: () async {
              if (r.id != null) {
                await _deleteRoutine(r.id!);
              }
            },
          ),
        );
      }

      // Add alarms
      for (int i = 0; i < _core.alarms.length; i++) {
        final a = _core.alarms[i];
        allItems.add(
          AlarmCard(
            alarm: a,
            onChanged: (val) async {
              final updatedAlarm = a.copyWith(enabled: val);
              await _saveAlarm(updatedAlarm);
            },
            onTap: () => _openEditAlarmSheet(i, a),
            onDelete: () async {
              if (a.id != null) {
                await _deleteAlarm(a.id!);
              }
            },
          ),
        );
      }

      content = allItems.isEmpty
          ? const Center(child: Text('No routines or alarms yet'))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomClearance + 16),
              children: allItems,
            );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text(
          'Routines & Alarms',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
        actions: sunriseSunsetEnabled
            ? [
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
              ]
            : null,
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          if (!sunriseSunsetEnabled)
            Positioned(
              left: 20,
              right: 20,
              bottom: bottomClearance + 24,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: ThemeManager.I.neumorphicGradient,
                          ),
                          boxShadow: ThemeManager.I.neumorphicShadows,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openAddRoutineSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Add Routine',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: ThemeManager.I.primaryTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: ThemeManager.I.neumorphicGradient,
                          ),
                          boxShadow: ThemeManager.I.neumorphicShadows,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openAddAlarmSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                'Add Alarm',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: ThemeManager.I.primaryTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Old _RoutineCard and _AlarmCard were extracted to widgets/routine_card.dart and widgets/alarm_card.dart
