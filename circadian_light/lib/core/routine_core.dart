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
  DuplicateAlarmException([this.message = 'Alarm already exists with the same specifications']);
  @override
  String toString() => message;
}

/// Core controller that encapsulates all routines/alarms logic and persistence.
/// UI layers (screens/widgets) should only consume this controller and display data.
class RoutineCore extends ChangeNotifier {
  RoutineCore();

  final List<Routine> _routines = [];
  final List<Alarm> _alarms = [];

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
  Future<Routine> saveRoutine(Routine routine) async {
    if (_isDuplicateRoutine(routine)) {
      throw DuplicateRoutineException();
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
  Future<Alarm> saveAlarm(Alarm alarm) async {
    if (_isDuplicateAlarm(alarm)) {
      throw DuplicateAlarmException();
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

  bool _isDuplicateRoutine(Routine newRoutine) {
    return _routines.any((existingRoutine) {
      if (newRoutine.id != null && existingRoutine.id == newRoutine.id) return false;
      final sameTimes = existingRoutine.startTime == newRoutine.startTime &&
          existingRoutine.endTime == newRoutine.endTime;
      final sameLevels = (existingRoutine.brightness - newRoutine.brightness).abs() < 0.01 &&
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
  static TimeOfDay calculateAlarmStartTime(TimeOfDay wakeUpTime, int durationMinutes) {
    final total = wakeUpTime.hour * 60 + wakeUpTime.minute - durationMinutes;
    final hour = ((total ~/ 60) % 24 + 24) % 24; // normalize
    final minute = (total % 60 + 60) % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

