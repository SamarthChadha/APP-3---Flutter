import 'package:flutter/material.dart';

// Model class representing an alarm for sunrise simulation

// Data class for alarm configuration with wake time, duration, and enable state
class Alarm {
  final int? id; // Database ID
  final String name;
  final TimeOfDay wakeUpTime;
  final int durationMinutes; // 10, 20, or 30
  bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Alarm({
    this.id,
    required this.name,
    required this.wakeUpTime,
    required this.durationMinutes,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Calculate start time (when lamp begins to brighten)
  TimeOfDay get startTime {
    final startMinutes =
        wakeUpTime.hour * 60 + wakeUpTime.minute - durationMinutes;
    final hour = (startMinutes ~/ 60) % 24;
    final minute = startMinutes % 60;
    return TimeOfDay(hour: hour < 0 ? hour + 24 : hour, minute: minute);
  }

  Alarm copyWith({
    int? id,
    String? name,
    TimeOfDay? wakeUpTime,
    int? durationMinutes,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Alarm(
    id: id ?? this.id,
    name: name ?? this.name,
    wakeUpTime: wakeUpTime ?? this.wakeUpTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'wake_up_hour': wakeUpTime.hour,
      'wake_up_minute': wakeUpTime.minute,
      'duration_minutes': durationMinutes,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from JSON/database row
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'] as int?,
      name: json['name'] as String,
      wakeUpTime: TimeOfDay(
        hour: json['wake_up_hour'] as int,
        minute: json['wake_up_minute'] as int,
      ),
      durationMinutes: json['duration_minutes'] as int,
      enabled: (json['enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  // Database table schema
  static const String tableName = 'alarms';

  static const String createTableSql =
      '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      wake_up_hour INTEGER NOT NULL,
      wake_up_minute INTEGER NOT NULL,
      duration_minutes INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alarm &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          wakeUpTime == other.wakeUpTime &&
          durationMinutes == other.durationMinutes &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      wakeUpTime.hashCode ^
      durationMinutes.hashCode ^
      enabled.hashCode;

  @override
  String toString() {
    return 'Alarm{id: $id, name: $name, wakeUpTime: $wakeUpTime, '
        'duration: ${durationMinutes}m, enabled: $enabled}';
  }
}
