import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/routine.dart';
import '../models/alarm.dart';

class SharedPreferencesStorage {
  static SharedPreferencesStorage? _instance;
  static SharedPreferences? _prefs;
  static final Logger _logger = Logger('SharedPreferencesStorage');

  SharedPreferencesStorage._internal();

  static SharedPreferencesStorage get instance {
    _instance ??= SharedPreferencesStorage._internal();
    return _instance!;
  }

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ==================== ROUTINE STORAGE ====================

  Future<void> saveRoutine(Routine routine) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String routineJson = jsonEncode(routine.toJson());
    await prefs.setString('routine_${routine.id}', routineJson);

    _logger.info('Saved routine ${routine.id} to SharedPreferences');
  }

  Future<Routine?> getRoutine(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final routineJson = prefs.getString('routine_$id');

    if (routineJson != null) {
      final Map<String, dynamic> json = jsonDecode(routineJson);
      return Routine.fromJson(json);
    }
    return null;
  }

  Future<List<Routine>> getAllRoutines() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('routine_'));

    List<Routine> routines = [];
    for (String key in keys) {
      final routineJson = prefs.getString(key);
      if (routineJson != null) {
        final Map<String, dynamic> json = jsonDecode(routineJson);
        routines.add(Routine.fromJson(json));
      }
    }

    // Sort by creation time
    routines.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return routines;
  }

  Future<void> deleteRoutine(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('routine_$id');

    _logger.info('Deleted routine $id from SharedPreferences');
  }

  Future<void> deleteAllRoutines() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('routine_'));

    for (String key in keys) {
      await prefs.remove(key);
    }

    _logger.info('Deleted all routines from SharedPreferences');
  }

  // ==================== ALARM STORAGE ====================

  Future<void> saveAlarm(Alarm alarm) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String alarmJson = jsonEncode(alarm.toJson());
    await prefs.setString('alarm_${alarm.id}', alarmJson);

    _logger.info('Saved alarm ${alarm.id} to SharedPreferences');
  }

  Future<Alarm?> getAlarm(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final alarmJson = prefs.getString('alarm_$id');

    if (alarmJson != null) {
      final Map<String, dynamic> json = jsonDecode(alarmJson);
      return Alarm.fromJson(json);
    }
    return null;
  }

  Future<List<Alarm>> getAllAlarms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('alarm_'));

    List<Alarm> alarms = [];
    for (String key in keys) {
      final alarmJson = prefs.getString(key);
      if (alarmJson != null) {
        final Map<String, dynamic> json = jsonDecode(alarmJson);
        alarms.add(Alarm.fromJson(json));
      }
    }

    // Sort by creation time
    alarms.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return alarms;
  }

  Future<void> deleteAlarm(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('alarm_$id');

    _logger.info('Deleted alarm $id from SharedPreferences');
  }

  Future<void> deleteAllAlarms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('alarm_'));

    for (String key in keys) {
      await prefs.remove(key);
    }

    _logger.info('Deleted all alarms from SharedPreferences');
  }

  // ==================== UTILITY METHODS ====================

  Future<void> clearAllData() async {
    await deleteAllRoutines();
    await deleteAllAlarms();

    _logger.info('Cleared all data from SharedPreferences');
  }

  Future<Map<String, dynamic>> exportData() async {
    final routines = await getAllRoutines();
    final alarms = await getAllAlarms();

    return {
      'routines': routines.map((r) => r.toJson()).toList(),
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    // Clear existing data
    await clearAllData();

    // Import routines
    if (data['routines'] != null) {
      for (final routineJson in data['routines']) {
        final routine = Routine.fromJson(routineJson);
        await saveRoutine(routine);
      }
    }

    // Import alarms
    if (data['alarms'] != null) {
      for (final alarmJson in data['alarms']) {
        final alarm = Alarm.fromJson(alarmJson);
        await saveAlarm(alarm);
      }
    }

    _logger.info('Imported data to SharedPreferences');
  }

  Future<int> getNextRoutineId() async {
    final routines = await getAllRoutines();
    if (routines.isEmpty) return 1;
    return routines.map((r) => r.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<int> getNextAlarmId() async {
    final alarms = await getAllAlarms();
    if (alarms.isEmpty) return 1;
    return alarms.map((a) => a.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
  }
}

// Convenience singleton accessor
SharedPreferencesStorage get sharedPrefsStorage => SharedPreferencesStorage.instance;