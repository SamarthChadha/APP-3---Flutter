import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../models/user_settings.dart';
import '../models/lamp_state.dart';
import 'esp_sync_service.dart';

/// Database service for persistent data storage and synchronization.
/// This service provides a data persistence layer for my circadian
/// lamp app, managing routines, alarms, user settings, and lamp state using
/// SQLite for structured data and SharedPreferences for simple
/// key-value storage.
/// Key features:
/// - User settings persistence using SharedPreferences
/// - Data export/import functionality for backup/restore
/// - Database integrity checks and automatic table creation

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  static SharedPreferences? _prefs;
  static final Logger _logger = Logger('DatabaseService');

  DatabaseService._internal();

  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  // Database version for migration management
  static const int _databaseVersion = 1;
  static const String _databaseName = 'circadian_light.db';

  /// Initializes both SQLite database and SharedPreferences.
  ///
  /// Must be called before any database operations. Sets up database connection
  /// with proper schema and initializes SharedPreferences for settings storage.
  Future<void> initialize() async {
    _database ??= await _initDatabase();
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
        // Ensure all required tables exist
        await _ensureTablesExist(db);
      },
    );

    return db;
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create routines table
    await db.execute(Routine.createTableSql);

    // Create alarms table
    await db.execute(Alarm.createTableSql);

    // Create lamp state table
    await db.execute(LampState.createTableSql);

    // Create app metadata table for tracking versions, etc.
    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    // Insert initial metadata
    await db.insert('app_metadata', {
      'key': 'db_version',
      'value': version.toString(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Ensure all required tables exist - handles missing tables gracefully
  Future<void> _ensureTablesExist(Database db) async {
    try {
      // Check if alarms table exists
      final alarmsTableExists = await _tableExists(db, 'alarms');
      if (!alarmsTableExists) {
        _logger.warning('Alarms table missing, creating it...');
        await db.execute(Alarm.createTableSql);
        _logger.info('Alarms table created successfully');
      }

      // Check if routines table exists
      final routinesTableExists = await _tableExists(db, 'routines');
      if (!routinesTableExists) {
        _logger.warning('Routines table missing, creating it...');
        await db.execute(Routine.createTableSql);
        _logger.info('Routines table created successfully');
      }

      // Check if app_metadata table exists
      final metadataTableExists = await _tableExists(db, 'app_metadata');
      if (!metadataTableExists) {
        _logger.warning('App metadata table missing, creating it...');
        await db.execute('''
          CREATE TABLE app_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        // Insert initial metadata
        await db.insert('app_metadata', {
          'key': 'db_version',
          'value': _databaseVersion.toString(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        _logger.info('App metadata table created successfully');
      }

      // Check if lamp_state table exists
      final lampStateTableExists = await _tableExists(db, 'lamp_state');
      if (!lampStateTableExists) {
        _logger.warning('Lamp state table missing, creating it...');
        await db.execute(LampState.createTableSql);
        _logger.info('Lamp state table created successfully');
      }
    } catch (e) {
      _logger.severe('Error ensuring tables exist: $e');
      rethrow;
    }
  }

  // Helper method to check if a table exists
  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      _logger.warning('Error checking if table $tableName exists: $e');
      return false;
    }
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Example migration for future version 2
      // await db.execute('ALTER TABLE routines ADD COLUMN new_field TEXT;');
    }

    // Update database version in metadata
    await db.update(
      'app_metadata',
      {
        'value': newVersion.toString(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'key = ?',
      whereArgs: ['db_version'],
    );
  }

  // Ensure database is initialized
  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  Future<SharedPreferences> get preferences async {
    if (_prefs == null) {
      await initialize();
    }
    return _prefs!;
  }

  // ==================== ROUTINE OPERATIONS ====================

  /// Saves a routine to the database with ESP32 synchronization.
  ///
  /// Inserts new routines or updates existing ones, then attempts to sync
  /// the routine to the connected ESP32 device. ESP sync failures are logged
  /// but don't prevent the database save from succeeding.
  Future<int> saveRoutine(Routine routine) async {
    final db = await database;

    int routineId;
    if (routine.id == null) {
      // Insert new routine
      routineId = await db.insert(Routine.tableName, routine.toJson());
    } else {
      // Update existing routine
      await db.update(
        Routine.tableName,
        routine.toJson(),
        where: 'id = ?',
        whereArgs: [routine.id],
      );
      routineId = routine.id!;
    }

    // Sync to ESP32 after successful database save
    try {
      final routineWithId = routine.copyWith(id: routineId);
      await EspSyncService.instance.syncRoutine(routineWithId);
    } catch (e) {
      // Don't fail the save operation if ESP sync fails
      _logger.warning('Failed to sync routine to ESP32: $e');
    }

    return routineId;
  }

  /// Get all routines from the database
  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      Routine.tableName,
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => Routine.fromJson(maps[i]));
  }

  /// Determines the currently active routine based on time.
  ///
  /// Checks all enabled routines to find which one encompasses the current
  /// time (or provided reference time). Returns the routine that will end
  /// soonest if multiple routines overlap.
  Future<Routine?> getActiveRoutine({DateTime? at}) async {
    final referenceTime = at ?? DateTime.now();
    final routines = await getAllRoutines();
    if (routines.isEmpty) return null;

    final time = TimeOfDay(
      hour: referenceTime.hour,
      minute: referenceTime.minute,
    );
    Routine? active;
    Duration? shortestUntilEnd;

    for (final routine in routines) {
      if (!routine.enabled) continue;
      if (_isTimeWithinRange(time, routine.startTime, routine.endTime)) {
        final untilEnd = _durationUntilEnd(referenceTime, routine.endTime);
        if (active == null || untilEnd < (shortestUntilEnd ?? untilEnd)) {
          active = routine;
          shortestUntilEnd = untilEnd;
        }
      }
    }

    return active;
  }

  bool _isTimeWithinRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final int timeMinutes = time.hour * 60 + time.minute;
    final int startMinutes = start.hour * 60 + start.minute;
    final int endMinutes = end.hour * 60 + end.minute;

    if (startMinutes == endMinutes) {
      // Covers full day when start == end
      return true;
    }

    if (startMinutes < endMinutes) {
      return timeMinutes >= startMinutes && timeMinutes < endMinutes;
    }

    // Range wraps past midnight
    return timeMinutes >= startMinutes || timeMinutes < endMinutes;
  }

  Duration _durationUntilEnd(DateTime reference, TimeOfDay end) {
    final DateTime endTimeToday = DateTime(
      reference.year,
      reference.month,
      reference.day,
      end.hour,
      end.minute,
    );
    DateTime adjustedEnd = endTimeToday;
    if (!reference.isBefore(adjustedEnd)) {
      adjustedEnd = adjustedEnd.add(const Duration(days: 1));
    }
    return adjustedEnd.difference(reference);
  }

  /// Get a specific routine by ID
  Future<Routine?> getRoutineById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      Routine.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Routine.fromJson(maps.first);
    }
    return null;
  }

  /// Delete a routine
  Future<void> deleteRoutine(int id) async {
    final db = await database;
    await db.delete(Routine.tableName, where: 'id = ?', whereArgs: [id]);

    // Sync deletion to ESP32
    try {
      await EspSyncService.instance.deleteRoutineFromEsp(id);
    } catch (e) {
      // Don't fail the delete operation if ESP sync fails
      _logger.warning('Failed to sync routine deletion to ESP32: $e');
    }
  }

  /// Delete all routines
  Future<void> deleteAllRoutines() async {
    final db = await database;
    await db.delete(Routine.tableName);
  }

  // ==================== ALARM OPERATIONS ====================

  /// Saves an alarm to the database with ESP32 synchronization.
  ///
  /// Inserts new alarms or updates existing ones, then attempts to sync
  /// the alarm to the connected ESP32 device. ESP sync failures are logged
  /// but don't prevent the database save from succeeding.
  Future<int> saveAlarm(Alarm alarm) async {
    final db = await database;

    int alarmId;
    if (alarm.id == null) {
      // Insert new alarm
      alarmId = await db.insert(Alarm.tableName, alarm.toJson());
    } else {
      // Update existing alarm
      await db.update(
        Alarm.tableName,
        alarm.toJson(),
        where: 'id = ?',
        whereArgs: [alarm.id],
      );
      alarmId = alarm.id!;
    }

    // Sync to ESP32 after successful database save
    try {
      final alarmWithId = alarm.copyWith(id: alarmId);
      await EspSyncService.instance.syncAlarm(alarmWithId);
    } catch (e) {
      // Don't fail the save operation if ESP sync fails
      _logger.warning('Failed to sync alarm to ESP32: $e');
    }

    return alarmId;
  }

  /// Get all alarms from the database
  Future<List<Alarm>> getAllAlarms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      Alarm.tableName,
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => Alarm.fromJson(maps[i]));
  }

  /// Get a specific alarm by ID
  Future<Alarm?> getAlarmById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      Alarm.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Alarm.fromJson(maps.first);
    }
    return null;
  }

  /// Delete an alarm
  Future<void> deleteAlarm(int id) async {
    final db = await database;
    await db.delete(Alarm.tableName, where: 'id = ?', whereArgs: [id]);

    // Sync deletion to ESP32
    try {
      await EspSyncService.instance.deleteAlarmFromEsp(id);
    } catch (e) {
      // Don't fail the delete operation if ESP sync fails
      _logger.warning('Failed to sync alarm deletion to ESP32: $e');
    }
  }

  /// Delete all alarms
  Future<void> deleteAllAlarms() async {
    final db = await database;
    await db.delete(Alarm.tableName);
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

  // ==================== LAMP STATE OPERATIONS ====================

  /// Save the current lamp state to database
  Future<void> saveLampState(LampState state) async {
    final db = await database;

    // Check if a lamp state record exists
    final existing = await db.query(LampState.tableName, limit: 1);

    if (existing.isEmpty) {
      // Insert new record
      await db.insert(LampState.tableName, state.toJson());
    } else {
      // Update existing record (there should only be one)
      await db.update(
        LampState.tableName,
        state.toJson(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }

    _logger.info('Saved lamp state: $state');
  }

  /// Load the current lamp state from database
  Future<LampState> getLampState() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      LampState.tableName,
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return LampState.fromJson(maps.first);
    }

    // Return default state if none exists
    final defaultState = LampState();
    await saveLampState(defaultState); // Save default state
    return defaultState;
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

  /// Clear all preferences (but not SQLite data)
  Future<void> clearPreferences() async {
    final prefs = await preferences;
    await prefs.clear();
  }

  // ==================== DATABASE MANAGEMENT ====================

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final routineCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ${Routine.tableName}'),
        ) ??
        0;

    return {'routines': routineCount};
  }

  /// Clear all data (both SQLite and SharedPreferences)
  Future<void> clearAllData() async {
    final db = await database;
    final prefs = await preferences;

    // Clear SQLite tables
    await db.delete(Routine.tableName);

    // Clear SharedPreferences
    await prefs.clear();
  }

  /// Export all data as JSON
  Future<Map<String, dynamic>> exportData() async {
    final routines = await getAllRoutines();
    final settings = await getUserSettings();

    return {
      'version': _databaseVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'routines': routines.map((r) => r.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;

    // Start a transaction to ensure data consistency
    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete(Routine.tableName);

      // Import routines
      if (data['routines'] != null) {
        for (final routineJson in data['routines']) {
          final routine = Routine.fromJson(routineJson);
          await txn.insert(Routine.tableName, routine.toJson());
        }
      }
    });

    // Import settings
    if (data['settings'] != null) {
      final settings = UserSettings.fromJson(data['settings']);
      await saveUserSettings(settings);
    }
  }

  /// Recreate the database from scratch (useful for fixing corruption or
  /// missing tables)
  Future<void> recreateDatabase() async {
    try {
      _logger.info('Recreating database from scratch...');

      // Close existing database
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Delete the database file
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _logger.info('Deleted existing database file');
      }

      // Reinitialize the database (this will trigger onCreate)
      _database = await _initDatabase();
      _logger.info('Database recreated successfully');
    } catch (e) {
      _logger.severe('Error recreating database: $e');
      rethrow;
    }
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

// Convenience singleton accessor
DatabaseService get db => DatabaseService.instance;
