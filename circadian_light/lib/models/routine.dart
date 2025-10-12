// Model representing a scheduled lighting routine with time range and settings

import 'package:flutter/material.dart';

class Routine {
  final int? id; // Database ID
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final double brightness;
  final double temperature; // store kelvin for editing
  bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Routine({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.brightness,
    required this.temperature,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Routine copyWith({
    int? id,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    double? brightness,
    double? temperature,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Routine(
    id: id ?? this.id,
    name: name ?? this.name,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    color: color ?? this.color,
    brightness: brightness ?? this.brightness,
    temperature: temperature ?? this.temperature,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_hour': startTime.hour, //breaking timeOfDay into Hour
      'start_minute': startTime.minute, //breaking timeOfDay into minutes
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
      'color_value': color.toARGB32(),
      'brightness': brightness,
      'temperature': temperature,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from JSON/database row
  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as int?,
      name: json['name'] as String,
      startTime: TimeOfDay(
        hour: json['start_hour'] as int,
        minute: json['start_minute'] as int,
      ),
      endTime: TimeOfDay(
        hour: json['end_hour'] as int,
        minute: json['end_minute'] as int,
      ),
      color: Color(json['color_value'] as int),
      brightness: (json['brightness'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      enabled: (json['enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  // Database table schema
  static const String tableName = 'routines';

  static const String createTableSql =
      '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      start_hour INTEGER NOT NULL,
      start_minute INTEGER NOT NULL,
      end_hour INTEGER NOT NULL,
      end_minute INTEGER NOT NULL,
      color_value INTEGER NOT NULL,
      brightness REAL NOT NULL,
      temperature REAL NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Routine &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          color == other.color &&
          brightness == other.brightness &&
          temperature == other.temperature &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      startTime.hashCode ^
      endTime.hashCode ^
      color.hashCode ^
      brightness.hashCode ^
      temperature.hashCode ^
      enabled.hashCode;

  @override
  String toString() {
    return 'Routine{id: $id, name: $name, startTime: $startTime, '
        'endTime: $endTime, enabled: $enabled}';
  }
}
