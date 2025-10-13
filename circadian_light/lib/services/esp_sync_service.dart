import 'dart:developer' as dev;
import '../core/esp_connection.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import 'database_service.dart';

/// Service for synchronizing routines and alarms between app and ESP32 device.
///
/// This service handles communication to ensure the ESP32 lamp
/// stays synchronized with the mobile app's routine and alarm configurations.
/// It manages time synchronization, data format conversion, and provides
/// detailed logging for debugging synchronization issues.
/// - Automatic state preservation during sync operations

class EspSyncService {
  EspSyncService._();
  static final EspSyncService instance = EspSyncService._();

  static const String _logTag = 'EspSyncService';

  /// Synchronizes current time to ESP32 for accurate scheduling.
  ///
  /// Sends UTC timestamp to ESP32 and logs detailed time information
  /// including expected Auckland time (NZDT UTC+13) for debugging.
  Future<void> syncTime() async {
    if (!EspConnection.instance.isConnected) {
      dev.log('🚫 ESP not connected - cannot sync time', name: _logTag);
      return;
    }

    // Get current time in UTC milliseconds
    final now = DateTime.now().toUtc();
    final timestamp = now.millisecondsSinceEpoch;

    // Calculate what Auckland time should be
    final aucklandTime = now.add(Duration(hours: 13)); // UTC+13 for NZDT

    dev.log('🕐 TIME SYNC DETAILS:', name: _logTag);
    dev.log('  UTC Time: ${now.toString()}', name: _logTag);
    dev.log('  UTC Timestamp: $timestamp', name: _logTag);
    dev.log(
      '  Expected Auckland Time: ${aucklandTime.toString()}',
      name: _logTag,
    );
    dev.log('  Offset: +13 hours (NZDT)', name: _logTag);

    final message = {'action': 'time_sync', 'timestamp': timestamp};

    try {
      EspConnection.instance.send(message);
      dev.log('✅ Time sync sent to ESP32', name: _logTag);
    } catch (e) {
      dev.log('❌ Failed to sync time: $e', name: _logTag);
    }
  }

  /// Sync a single routine to ESP32 with time sync and state preservation
  Future<bool> syncRoutine(Routine routine) async {
    try {
      if (!EspConnection.instance.isConnected) {
        dev.log('Cannot sync routine: ESP32 not connected', name: _logTag);
        return false;
      }

      // First sync time to ensure ESP32 has accurate time
      await syncTime();

      final routineData = _routineToEspFormat(routine);
      final syncMessage = {
        'type': 'routine_sync',
        'action': 'upsert', // update or insert
        'data': routineData,
        'preserve_state':
            true, // Tell ESP32 to preserve current state before routine starts
      };

      EspConnection.instance.send(syncMessage);

      // Detailed logging for debugging
      dev.log('📅 Routine sync sent to ESP32:', name: _logTag);
      dev.log('  - Name: "${routine.name}"', name: _logTag);
      dev.log('  - ID: ${routine.id}', name: _logTag);
      dev.log('  - Enabled: ${routine.enabled}', name: _logTag);
      final startTimeStr =
          '  - Start time: '
          '${routine.startTime.hour.toString().padLeft(2, '0')}:'
          '${routine.startTime.minute.toString().padLeft(2, '0')}';
      dev.log(startTimeStr, name: _logTag);
      final endTimeStr =
          '  - End time: '
          '${routine.endTime.hour.toString().padLeft(2, '0')}:'
          '${routine.endTime.minute.toString().padLeft(2, '0')}';
      dev.log(endTimeStr, name: _logTag);
      final brightnessStr =
          '  - Brightness: '
          '${routine.brightness.toStringAsFixed(1)}% '
          '(ESP32: ${routineData['brightness']})';
      dev.log(brightnessStr, name: _logTag);
      dev.log(
        '  - Temperature: ${routine.temperature.toStringAsFixed(0)}K',
        name: _logTag,
      );
      final modeStr =
          '  - Mode: '
          '${_temperatureToMode(routine.temperature)} '
          '(${_getModeDescription(_temperatureToMode(routine.temperature))})';
      dev.log(modeStr, name: _logTag);

      // Calculate time until routine starts (in Auckland timezone)
      final aucklandNow = DateTime.now().toUtc().add(
        const Duration(hours: 13),
      ); // UTC+13 for NZDT
      final todayStart = DateTime(
        aucklandNow.year,
        aucklandNow.month,
        aucklandNow.day,
        routine.startTime.hour,
        routine.startTime.minute,
      );
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final nextStart = todayStart.isAfter(aucklandNow)
          ? todayStart
          : tomorrowStart;
      final timeUntilStart = nextStart.difference(aucklandNow);

      if (routine.enabled) {
        final nextStartStr =
            '  - Next start: '
            '${nextStart.toString()} NZDT '
            '(in ${_formatDuration(timeUntilStart)})';
        dev.log(nextStartStr, name: _logTag);
      } else {
        dev.log('  - Status: DISABLED - will not run', name: _logTag);
      }

      return true;
    } catch (e) {
      dev.log('Failed to sync routine: $e', name: _logTag);
      return false;
    }
  }

  /// Sync a single alarm to ESP32 with time sync and state preservation
  Future<bool> syncAlarm(Alarm alarm) async {
    try {
      if (!EspConnection.instance.isConnected) {
        dev.log('Cannot sync alarm: ESP32 not connected', name: _logTag);
        return false;
      }

      // First sync time to ensure ESP32 has accurate time
      await syncTime();

      final alarmData = _alarmToEspFormat(alarm);
      final syncMessage = {
        'type': 'alarm_sync',
        'action': 'upsert', // update or insert
        'data': alarmData,
        'preserve_state':
            true, // Tell ESP32 to preserve current state before alarm starts
      };

      EspConnection.instance.send(syncMessage);

      // Detailed logging for debugging
      dev.log('⏰ Alarm sync sent to ESP32:', name: _logTag);
      dev.log('  - Name: "${alarm.name}"', name: _logTag);
      dev.log('  - ID: ${alarm.id}', name: _logTag);
      dev.log('  - Enabled: ${alarm.enabled}', name: _logTag);
      final wakeUpTimeStr =
          '  - Wake-up time: '
          '${alarm.wakeUpTime.hour.toString().padLeft(2, '0')}:'
          '${alarm.wakeUpTime.minute.toString().padLeft(2, '0')}';
      dev.log(wakeUpTimeStr, name: _logTag);
      final alarmStartTimeStr =
          '  - Start time: '
          '${alarm.startTime.hour.toString().padLeft(2, '0')}:'
          '${alarm.startTime.minute.toString().padLeft(2, '0')}';
      dev.log(alarmStartTimeStr, name: _logTag);
      dev.log('  - Duration: ${alarm.durationMinutes} minutes', name: _logTag);
      dev.log('  - Mode: Warm light sunrise simulation', name: _logTag);

      // Calculate time until alarm starts (in Auckland timezone)
      final aucklandNow = DateTime.now().toUtc().add(
        const Duration(hours: 13),
      ); // UTC+13 for NZDT
      final todayStart = DateTime(
        aucklandNow.year,
        aucklandNow.month,
        aucklandNow.day,
        alarm.startTime.hour,
        alarm.startTime.minute,
      );
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final nextStart = todayStart.isAfter(aucklandNow)
          ? todayStart
          : tomorrowStart;
      final timeUntilStart = nextStart.difference(aucklandNow);

      if (alarm.enabled) {
        final alarmNextStartStr =
            '  - Next start: '
            '${nextStart.toString()} NZDT '
            '(in ${_formatDuration(timeUntilStart)})';
        dev.log(alarmNextStartStr, name: _logTag);
      } else {
        dev.log('  - Status: DISABLED - will not run', name: _logTag);
      }

      return true;
    } catch (e) {
      dev.log('Failed to sync alarm: $e', name: _logTag);
      return false;
    }
  }

  /// Sync all routines and alarms to ESP32 with time sync
  Future<bool> syncAll() async {
    try {
      if (!EspConnection.instance.isConnected) {
        dev.log('Cannot sync all: ESP32 not connected', name: _logTag);
        return false;
      }

      // First sync time to ensure ESP32 has accurate time
      await syncTime();

      // Get all routines and alarms from database
      final routines = await db.getAllRoutines();
      final alarms = await db.getAllAlarms();

      // Prepare data for bulk sync
      final allData = {
        'type': 'full_sync',
        'routines': routines.map((r) => _routineToEspFormat(r)).toList(),
        'alarms': alarms.map((a) => _alarmToEspFormat(a)).toList(),
        'preserve_state': true, // Tell ESP32 to preserve current state
      };

      EspConnection.instance.send(allData);
      final syncAllStr =
          'Synced ${routines.length} routines and '
          '${alarms.length} alarms to ESP32 with time and state preservation';
      dev.log(syncAllStr, name: _logTag);
      return true;
    } catch (e) {
      dev.log('Failed to sync all data: $e', name: _logTag);
      return false;
    }
  }

  /// Delete a routine from ESP32
  Future<bool> deleteRoutineFromEsp(int routineId) async {
    try {
      if (!EspConnection.instance.isConnected) {
        dev.log('Cannot delete routine: ESP32 not connected', name: _logTag);
        return false;
      }

      EspConnection.instance.send({
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
      if (!EspConnection.instance.isConnected) {
        dev.log('Cannot delete alarm: ESP32 not connected', name: _logTag);
        return false;
      }

      EspConnection.instance.send({
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
    // Convert brightness from percentage (0-100) to ESP32 range (1-15)
    // Ensure minimum brightness of 1 when enabled
    final espBrightness = routine.enabled
        ? ((routine.brightness / 100.0) * 14 + 1).round().clamp(1, 15)
        : 1;

    return {
      'id': routine.id,
      'name': routine.name,
      'enabled': routine.enabled,
      'start_hour': routine.startTime.hour,
      'start_minute': routine.startTime.minute,
      'end_hour': routine.endTime.hour,
      'end_minute': routine.endTime.minute,
      'brightness': espBrightness,
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

  /// Get human-readable mode description
  String _getModeDescription(int mode) {
    switch (mode) {
      case 0:
        return 'Warm Light';
      case 1:
        return 'White Light';
      case 2:
        return 'Mixed Light';
      default:
        return 'Unknown';
    }
  }

  /// Format duration for human-readable display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h '
          '${duration.inMinutes % 60}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Attempt to sync when ESP32 reconnects
  /// This should be called when the ESP32 connection is established
  Future<void> onEspConnected() async {
    dev.log(
      'ESP32 connected, initiating full sync with time sync...',
      name: _logTag,
    );
    await syncTime(); // Sync time first
    await syncAll(); // Then sync all data
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
