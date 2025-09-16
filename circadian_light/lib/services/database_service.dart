import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../models/user_settings.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  static SharedPreferences? _prefs;

  DatabaseService._internal();

  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  // Database version for migration management
  static const int _databaseVersion = 1;
  static const String _databaseName = 'circadian_light.db';

  // Initialize both SQLite database and SharedPreferences
  Future<void> initialize() async {
    _database ??= await _initDatabase();
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      onOpen: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create routines table
    await db.execute(Routine.createTableSql);
    
    // Create alarms table
    await db.execute(Alarm.createTableSql);
    
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

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
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

  /// Save a routine to the database
  Future<int> saveRoutine(Routine routine) async {
    final db = await database;
    
    if (routine.id == null) {
      // Insert new routine
      return await db.insert(Routine.tableName, routine.toJson());
    } else {
      // Update existing routine
      await db.update(
        Routine.tableName,
        routine.toJson(),
        where: 'id = ?',
        whereArgs: [routine.id],
      );
      return routine.id!;
    }
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
    await db.delete(
      Routine.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all routines
  Future<void> deleteAllRoutines() async {
    final db = await database;
    await db.delete(Routine.tableName);
  }

  // ==================== ALARM OPERATIONS ====================

  /// Save an alarm to the database
  Future<int> saveAlarm(Alarm alarm) async {
    final db = await database;
    
    if (alarm.id == null) {
      // Insert new alarm
      return await db.insert(Alarm.tableName, alarm.toJson());
    } else {
      // Update existing alarm
      await db.update(
        Alarm.tableName,
        alarm.toJson(),
        where: 'id = ?',
        whereArgs: [alarm.id],
      );
      return alarm.id!;
    }
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
    await db.delete(
      Alarm.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
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
    
    final routineCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${Routine.tableName}'),
    ) ?? 0;

    return {
      'routines': routineCount,
    };
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