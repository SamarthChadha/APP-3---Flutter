import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../models/user_settings.dart';
import '../models/lamp_state.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;
  static final Logger _logger = Logger('StorageService');

  StorageService._internal();

  static StorageService get instance {
    _instance ??= StorageService._internal();
    return _instance!;
  }

  // Initialize SharedPreferences
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ==================== ROUTINE OPERATIONS ====================

  static const String _routinesKey = 'routines';

  /// Save a routine to SharedPreferences
  Future<int> saveRoutine(Routine routine) async {
    final prefs = await preferences;
    final routines = await getAllRoutines();

    int routineId;
    if (routine.id == null) {
      // Generate new ID
      routineId = DateTime.now().millisecondsSinceEpoch;
      routine = routine.copyWith(id: routineId);
      routines.add(routine);
    } else {
      // Update existing routine
      routineId = routine.id!;
      final index = routines.indexWhere((r) => r.id == routineId);
      if (index != -1) {
        routines[index] = routine;
      } else {
        routines.add(routine);
      }
    }

    final routinesJson = routines.map((r) => r.toJson()).toList();
    await prefs.setString(_routinesKey, jsonEncode(routinesJson));

    return routineId;
  }

  /// Get all routines from SharedPreferences
  Future<List<Routine>> getAllRoutines() async {
    final prefs = await preferences;
    final routinesString = prefs.getString(_routinesKey);

    if (routinesString != null) {
      final List<dynamic> routinesJson = jsonDecode(routinesString);
      return routinesJson.map((json) => Routine.fromJson(json)).toList();
    }

    return [];
  }

  /// Get a specific routine by ID
  Future<Routine?> getRoutineById(int id) async {
    final routines = await getAllRoutines();
    try {
      return routines.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete a routine
  Future<void> deleteRoutine(int id) async {
    final prefs = await preferences;
    final routines = await getAllRoutines();
    routines.removeWhere((r) => r.id == id);

    final routinesJson = routines.map((r) => r.toJson()).toList();
    await prefs.setString(_routinesKey, jsonEncode(routinesJson));
  }

  /// Delete all routines
  Future<void> deleteAllRoutines() async {
    final prefs = await preferences;
    await prefs.remove(_routinesKey);
  }

  // ==================== ALARM OPERATIONS ====================

  static const String _alarmsKey = 'alarms';

  /// Save an alarm to SharedPreferences
  Future<int> saveAlarm(Alarm alarm) async {
    final prefs = await preferences;
    final alarms = await getAllAlarms();

    int alarmId;
    if (alarm.id == null) {
      // Generate new ID
      alarmId = DateTime.now().millisecondsSinceEpoch;
      alarm = alarm.copyWith(id: alarmId);
      alarms.add(alarm);
    } else {
      // Update existing alarm
      alarmId = alarm.id!;
      final index = alarms.indexWhere((a) => a.id == alarmId);
      if (index != -1) {
        alarms[index] = alarm;
      } else {
        alarms.add(alarm);
      }
    }

    final alarmsJson = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));

    return alarmId;
  }

  /// Get all alarms from SharedPreferences
  Future<List<Alarm>> getAllAlarms() async {
    final prefs = await preferences;
    final alarmsString = prefs.getString(_alarmsKey);

    if (alarmsString != null) {
      final List<dynamic> alarmsJson = jsonDecode(alarmsString);
      return alarmsJson.map((json) => Alarm.fromJson(json)).toList();
    }

    return [];
  }

  /// Get a specific alarm by ID
  Future<Alarm?> getAlarmById(int id) async {
    final alarms = await getAllAlarms();
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Delete an alarm
  Future<void> deleteAlarm(int id) async {
    final prefs = await preferences;
    final alarms = await getAllAlarms();
    alarms.removeWhere((a) => a.id == id);

    final alarmsJson = alarms.map((a) => a.toJson()).toList();
    await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
  }

  /// Delete all alarms
  Future<void> deleteAllAlarms() async {
    final prefs = await preferences;
    await prefs.remove(_alarmsKey);
  }

  // ==================== USER SETTINGS OPERATIONS ====================

  static const String _settingsKey = 'user_settings';

  /// Save user settings to SharedPreferences
  Future<void> saveUserSettings(UserSettings settings) async {
    final prefs = await preferences;
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }

  /// Load user settings from SharedPreferences
  Future<UserSettings> getUserSettings() async {
    final prefs = await preferences;
    final jsonString = prefs.getString(_settingsKey);

    if (jsonString != null) {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return UserSettings.fromJson(json);
    }

    // Return default settings if none exist
    return UserSettings();
  }

  // ==================== LAMP STATE OPERATIONS ====================

  static const String _lampStateKey = 'lamp_state';

  /// Save the current lamp state to SharedPreferences
  Future<void> saveLampState(LampState state) async {
    final prefs = await preferences;
    await prefs.setString(_lampStateKey, jsonEncode(state.toJson()));
    _logger.info('Saved lamp state: $state');
  }

  /// Load the current lamp state from SharedPreferences
  Future<LampState> getLampState() async {
    final prefs = await preferences;
    final stateString = prefs.getString(_lampStateKey);

    if (stateString != null) {
      final Map<String, dynamic> json = jsonDecode(stateString);
      return LampState.fromJson(json);
    }

    // Return default state if none exists
    final defaultState = LampState();
    await saveLampState(defaultState); // Save default state
    return defaultState;
  }

  // ==================== SIMPLE PREFERENCE OPERATIONS ====================

  /// Save a simple string preference
  Future<void> setString(String key, String value) async {
    final prefs = await preferences;
    await prefs.setString(key, value);
  }

  /// Get a simple string preference
  Future<String?> getString(String key) async {
    final prefs = await preferences;
    return prefs.getString(key);
  }

  /// Save a simple boolean preference
  Future<void> setBool(String key, bool value) async {
    final prefs = await preferences;
    await prefs.setBool(key, value);
  }

  /// Get a simple boolean preference
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await preferences;
    return prefs.getBool(key) ?? defaultValue;
  }

  /// Save a simple integer preference
  Future<void> setInt(String key, int value) async {
    final prefs = await preferences;
    await prefs.setInt(key, value);
  }

  /// Get a simple integer preference
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final prefs = await preferences;
    return prefs.getInt(key) ?? defaultValue;
  }

  /// Save a simple double preference
  Future<void> setDouble(String key, double value) async {
    final prefs = await preferences;
    await prefs.setDouble(key, value);
  }

  /// Get a simple double preference
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final prefs = await preferences;
    return prefs.getDouble(key) ?? defaultValue;
  }

  /// Remove a preference
  Future<void> remove(String key) async {
    final prefs = await preferences;
    await prefs.remove(key);
  }

  /// Clear all preferences
  Future<void> clearAllData() async {
    final prefs = await preferences;
    await prefs.clear();
  }

  /// Export all data as JSON
  Future<Map<String, dynamic>> exportData() async {
    final routines = await getAllRoutines();
    final alarms = await getAllAlarms();
    final settings = await getUserSettings();
    final lampState = await getLampState();

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'routines': routines.map((r) => r.toJson()).toList(),
      'alarms': alarms.map((a) => a.toJson()).toList(),
      'settings': settings.toJson(),
      'lamp_state': lampState.toJson(),
    };
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    final prefs = await preferences;

    // Clear existing data
    await clearAllData();

    // Import routines
    if (data['routines'] != null) {
      final routinesJson = (data['routines'] as List).map((r) => r as Map<String, dynamic>).toList();
      await prefs.setString(_routinesKey, jsonEncode(routinesJson));
    }

    // Import alarms
    if (data['alarms'] != null) {
      final alarmsJson = (data['alarms'] as List).map((a) => a as Map<String, dynamic>).toList();
      await prefs.setString(_alarmsKey, jsonEncode(alarmsJson));
    }

    // Import settings
    if (data['settings'] != null) {
      final settings = UserSettings.fromJson(data['settings']);
      await saveUserSettings(settings);
    }

    // Import lamp state
    if (data['lamp_state'] != null) {
      final lampState = LampState.fromJson(data['lamp_state']);
      await saveLampState(lampState);
    }
  }
}

// Convenience singleton accessor
StorageService get storage => StorageService.instance;