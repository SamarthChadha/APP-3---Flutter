import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/alarm.dart';
import '../models/routine.dart';
import '../services/database_service.dart';
import '../services/esp_sync_service.dart';
import '../core/esp_connection.dart';

/// Thrown when attempting to save a routine that duplicates another
class DuplicateRoutineException implements Exception {
  final String message;
  DuplicateRoutineException([this.message = 'Routine already exists.']);
  @override
  String toString() => message;
}

/// Thrown when attempting to save an alarm that duplicates another
class DuplicateAlarmException implements Exception {
  final String message;
  DuplicateAlarmException([
    this.message = 'Alarm already exists with the same specifications',
  ]);
  @override
  String toString() => message;
}

/// Core controller that encapsulates all routines/alarms logic and persistence.
/// UI layers (screens/widgets) should only consume this controller and display data.
class RoutineCore extends ChangeNotifier {
  RoutineCore();

  final List<Routine> _routines = [];
  final List<Alarm> _alarms = [];

  // Mutex to prevent simultaneous routine/alarm activations
  bool _isActivating = false;

  List<Routine> get routines => List.unmodifiable(_routines);
  List<Alarm> get alarms => List.unmodifiable(_alarms);

  /// Initialize by loading routines and alarms
  Future<void> init() async {
    await Future.wait([_loadRoutines(), _loadAlarms()]);
    notifyListeners();
  }

  Future<void> _loadRoutines() async {
    final items = await db.getAllRoutines();
    _routines
      ..clear()
      ..addAll(items);
  }

  Future<void> _loadAlarms() async {
    final items = await db.getAllAlarms();
    _alarms
      ..clear()
      ..addAll(items);
  }

  /// Save or update a routine. Throws [DuplicateRoutineException] on duplicate.
  /// Also syncs to ESP32 if connected.
  /// If the routine is enabled, disables all overlapping routines and alarms.
  Future<Routine> saveRoutine(Routine routine) async {
    if (_isDuplicateRoutine(routine)) {
      throw DuplicateRoutineException();
    }

    // If this routine is being enabled, use mutex to prevent race condition
    if (routine.enabled) {
      // Check if another activation is in progress
      if (_isActivating) {
        // Another routine/alarm is being activated, reject this operation
        return _routines.firstWhere(
          (r) => r.id == routine.id,
          orElse: () => routine.copyWith(enabled: false),
        );
      }

      // Acquire the lock
      _isActivating = true;
      try {
        // Disable all overlapping items
        await _disableOverlappingItems(
          routine.startTime,
          routine.endTime,
          routine.id,
          'routine',
        );
      } finally {
        // Always release the lock, even if an error occurs
        _isActivating = false;
      }
    }

    final id = await db.saveRoutine(routine);
    final saved = routine.copyWith(id: id);

    final index = _routines.indexWhere((r) => r.id == saved.id);
    if (index >= 0) {
      _routines[index] = saved;
    } else {
      _routines.add(saved);
    }
    notifyListeners();

    // Sync to ESP32 if connected and enabled
    if (EspConnection.I.isConnected && saved.enabled) {
      EspSyncService.I.syncRoutine(saved);
    }

    return saved;
  }

  Future<void> deleteRoutine(int id) async {
    await db.deleteRoutine(id);
    _routines.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// Save or update an alarm. Throws [DuplicateAlarmException] on duplicate.
  /// Also syncs to ESP32 if connected.
  /// If the alarm is enabled, disables all overlapping routines and alarms.
  Future<Alarm> saveAlarm(Alarm alarm) async {
    if (_isDuplicateAlarm(alarm)) {
      throw DuplicateAlarmException();
    }

    // If this alarm is being enabled, use mutex to prevent race condition
    if (alarm.enabled) {
      // Check if another activation is in progress
      if (_isActivating) {
        // Another routine/alarm is being activated, reject this operation
        return _alarms.firstWhere(
          (a) => a.id == alarm.id,
          orElse: () => alarm.copyWith(enabled: false),
        );
      }

      // Acquire the lock
      _isActivating = true;
      try {
        // Disable all overlapping items
        await _disableOverlappingItems(
          alarm.startTime,
          alarm.wakeUpTime,
          alarm.id,
          'alarm',
        );
      } finally {
        // Always release the lock, even if an error occurs
        _isActivating = false;
      }
    }

    final id = await db.saveAlarm(alarm);
    final saved = alarm.copyWith(id: id);
    final index = _alarms.indexWhere((a) => a.id == saved.id);
    if (index >= 0) {
      _alarms[index] = saved;
    } else {
      _alarms.add(saved);
    }
    notifyListeners();

    // Sync to ESP32 if connected and enabled
    if (EspConnection.I.isConnected && saved.enabled) {
      EspSyncService.I.syncAlarm(saved);
    }

    return saved;
  }

  Future<void> deleteAlarm(int id) async {
    await db.deleteAlarm(id);
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // ===================== Helpers =====================

  /// Convert TimeOfDay to total minutes since midnight
  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Check if two time ranges overlap, accounting for 24-hour wraparound
  bool _timeRangesOverlap(
    TimeOfDay start1,
    TimeOfDay end1,
    TimeOfDay start2,
    TimeOfDay end2,
  ) {
    final s1 = _toMinutes(start1);
    final e1 = _toMinutes(end1);
    final s2 = _toMinutes(start2);
    final e2 = _toMinutes(end2);

    final wraps1 = s1 > e1; // first range wraps midnight
    final wraps2 = s2 > e2; // second range wraps midnight

    if (!wraps1 && !wraps2) {
      // Neither wraps: standard overlap check
      return s1 < e2 && s2 < e1;
    } else if (wraps1 && wraps2) {
      // Both wrap: they always overlap
      return true;
    } else if (wraps1) {
      // Only first wraps: [s1, 24h) + [0, e1) overlaps with [s2, e2)
      return s2 < e1 || e2 > s1;
    } else {
      // Only second wraps: [s2, 24h) + [0, e2) overlaps with [s1, e1)
      return s1 < e2 || e1 > s2;
    }
  }

  /// Disable all routines and alarms that overlap with the given time range
  Future<void> _disableOverlappingItems(
    TimeOfDay startTime,
    TimeOfDay endTime,
    int? excludeId,
    String excludeType, // 'routine' or 'alarm'
  ) async {
    // Find overlapping routines
    for (final routine in _routines) {
      // Skip the routine being saved
      if (excludeType == 'routine' && routine.id == excludeId) continue;

      // Skip if already disabled
      if (!routine.enabled) continue;

      // Check for overlap
      if (_timeRangesOverlap(
        startTime,
        endTime,
        routine.startTime,
        routine.endTime,
      )) {
        // Disable this routine
        final disabled = routine.copyWith(enabled: false);
        await db.saveRoutine(disabled);

        final index = _routines.indexWhere((r) => r.id == routine.id);
        if (index >= 0) {
          _routines[index] = disabled;
        }

        // Sync disabled state to ESP32 if connected
        if (EspConnection.I.isConnected) {
          EspSyncService.I.syncRoutine(disabled);
        }
      }
    }

    // Find overlapping alarms
    for (final alarm in _alarms) {
      // Skip the alarm being saved
      if (excludeType == 'alarm' && alarm.id == excludeId) continue;

      // Skip if already disabled
      if (!alarm.enabled) continue;

      // Check for overlap
      if (_timeRangesOverlap(
        startTime,
        endTime,
        alarm.startTime,
        alarm.wakeUpTime,
      )) {
        // Disable this alarm
        final disabled = alarm.copyWith(enabled: false);
        await db.saveAlarm(disabled);

        final index = _alarms.indexWhere((a) => a.id == alarm.id);
        if (index >= 0) {
          _alarms[index] = disabled;
        }

        // Sync disabled state to ESP32 if connected
        if (EspConnection.I.isConnected) {
          EspSyncService.I.syncAlarm(disabled);
        }
      }
    }
  }

  bool _isDuplicateRoutine(Routine newRoutine) {
    return _routines.any((existingRoutine) {
      if (newRoutine.id != null && existingRoutine.id == newRoutine.id) {
        return false;
      }
      final sameTimes =
          existingRoutine.startTime == newRoutine.startTime &&
          existingRoutine.endTime == newRoutine.endTime;
      final sameLevels =
          (existingRoutine.brightness - newRoutine.brightness).abs() < 0.01 &&
          (existingRoutine.temperature - newRoutine.temperature).abs() < 0.01;
      return sameTimes && sameLevels;
    });
  }

  bool _isDuplicateAlarm(Alarm newAlarm) {
    return _alarms.any((existingAlarm) {
      if (newAlarm.id != null && existingAlarm.id == newAlarm.id) return false;
      return existingAlarm.wakeUpTime == newAlarm.wakeUpTime &&
          existingAlarm.durationMinutes == newAlarm.durationMinutes;
    });
  }

  /// Convert color temperature (Kelvin) to an approximate RGB color swatch
  static Color colorFromTemperature(double kelvin) {
    double t = kelvin / 100.0;
    double r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.4708025861 * (t <= 0 ? 0.0001 : math.log(t)) - 161.1195681661;
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

  /// Calculate the start time given a wake-up time and ramp duration
  static TimeOfDay calculateAlarmStartTime(
    TimeOfDay wakeUpTime,
    int durationMinutes,
  ) {
    final total = wakeUpTime.hour * 60 + wakeUpTime.minute - durationMinutes;
    final hour = ((total ~/ 60) % 24 + 24) % 24; // normalize
    final minute = (total % 60 + 60) % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
