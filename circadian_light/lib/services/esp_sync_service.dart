import 'dart:developer' as dev;
import '../core/esp_connection.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import 'database_service.dart';

/// Service responsible for synchronizing routines and alarms to ESP32
/// Ensures the lamp can function independently even when app is disconnected
class EspSyncService {
  EspSyncService._();
  static final EspSyncService I = EspSyncService._();

  static const String _logTag = 'EspSyncService';

  /// Sync a single routine to ESP32
  Future<bool> syncRoutine(Routine routine) async {
    try {
      if (!EspConnection.I.isConnected) {
        dev.log('Cannot sync routine: ESP32 not connected', name: _logTag);
        return false;
      }

      final routineData = _routineToEspFormat(routine);
      EspConnection.I.send({
        'type': 'routine_sync',
        'action': 'upsert', // update or insert
        'data': routineData,
      });

      dev.log('Synced routine "${routine.name}" to ESP32', name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to sync routine: $e', name: _logTag);
      return false;
    }
  }

  /// Sync a single alarm to ESP32
  Future<bool> syncAlarm(Alarm alarm) async {
    try {
      if (!EspConnection.I.isConnected) {
        dev.log('Cannot sync alarm: ESP32 not connected', name: _logTag);
        return false;
      }

      final alarmData = _alarmToEspFormat(alarm);
      EspConnection.I.send({
        'type': 'alarm_sync',
        'action': 'upsert', // update or insert
        'data': alarmData,
      });

      dev.log('Synced alarm "${alarm.name}" to ESP32', name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to sync alarm: $e', name: _logTag);
      return false;
    }
  }

  /// Sync all routines and alarms to ESP32
  Future<bool> syncAll() async {
    try {
      if (!EspConnection.I.isConnected) {
        dev.log('Cannot sync all: ESP32 not connected', name: _logTag);
        return false;
      }

            // Get all routines and alarms from database
      final routines = await DatabaseService.instance.getAllRoutines();
      final alarms = await DatabaseService.instance.getAllAlarms();

      // Prepare sync data
      final syncData = {
        'type': 'full_sync',
        'routines': routines.map(_routineToEspFormat).toList(),
        'alarms': alarms.map(_alarmToEspFormat).toList(),
      };

      EspConnection.I.send(syncData);

      dev.log('Synced all data to ESP32: ${routines.length} routines, ${alarms.length} alarms', name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to sync all data: $e', name: _logTag);
      return false;
    }
  }

  /// Delete a routine from ESP32
  Future<bool> deleteRoutineFromEsp(int routineId) async {
    try {
      if (!EspConnection.I.isConnected) {
        dev.log('Cannot delete routine: ESP32 not connected', name: _logTag);
        return false;
      }

      EspConnection.I.send({
        'type': 'routine_sync',
        'action': 'delete',
        'id': routineId,
      });

      dev.log('Deleted routine $routineId from ESP32', name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to delete routine from ESP32: $e', name: _logTag);
      return false;
    }
  }

  /// Delete an alarm from ESP32
  Future<bool> deleteAlarmFromEsp(int alarmId) async {
    try {
      if (!EspConnection.I.isConnected) {
        dev.log('Cannot delete alarm: ESP32 not connected', name: _logTag);
        return false;
      }

      EspConnection.I.send({
        'type': 'alarm_sync',
        'action': 'delete',
        'id': alarmId,
      });

      dev.log('Deleted alarm $alarmId from ESP32', name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to delete alarm from ESP32: $e', name: _logTag);
      return false;
    }
  }

  /// Convert routine to ESP32-friendly format
  Map<String, dynamic> _routineToEspFormat(Routine routine) {
    return {
      'id': routine.id,
      'name': routine.name,
      'enabled': routine.enabled,
      'start_hour': routine.startTime.hour,
      'start_minute': routine.startTime.minute,
      'end_hour': routine.endTime.hour,
      'end_minute': routine.endTime.minute,
      'brightness': (routine.brightness * 15).round(), // Convert 0.0-1.0 to 0-15 for ESP32
      'temperature_kelvin': routine.temperature.round(),
      'mode': _temperatureToMode(routine.temperature),
    };
  }

  /// Convert alarm to ESP32-friendly format
  Map<String, dynamic> _alarmToEspFormat(Alarm alarm) {
    return {
      'id': alarm.id,
      'name': alarm.name,
      'enabled': alarm.enabled,
      'wake_hour': alarm.wakeUpTime.hour,
      'wake_minute': alarm.wakeUpTime.minute,
      'start_hour': alarm.startTime.hour,
      'start_minute': alarm.startTime.minute,
      'duration_minutes': alarm.durationMinutes,
    };
  }

  /// Convert temperature (Kelvin) to ESP32 mode
  /// This matches the logic in ESP32 firmware
  int _temperatureToMode(double kelvin) {
    if (kelvin <= 3500) {
      return 0; // MODE_WARM
    } else if (kelvin >= 5500) {
      return 1; // MODE_WHITE
    } else {
      return 2; // MODE_BOTH (mixed)
    }
  }

  /// Attempt to sync when ESP32 reconnects
  /// This should be called when the ESP32 connection is established
  Future<void> onEspConnected() async {
    dev.log('ESP32 connected, initiating full sync...', name: _logTag);
    await syncAll();
  }

  /// Handle ESP32 sync response
  void handleSyncResponse(Map<String, dynamic> response) {
    final type = response['type'] as String?;
    final success = response['success'] as bool? ?? false;
    final message = response['message'] as String?;

    if (success) {
      dev.log('ESP32 sync success: $type - $message', name: _logTag);
    } else {
      dev.log('ESP32 sync failed: $type - $message', name: _logTag);
    }
  }
}