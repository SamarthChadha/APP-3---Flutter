// Model representing the current state of the lamp including brightness, mode, and temperature

/// Model representing the current state of the lamp
/// This includes on/off status, brightness, and color temperature
class LampState {
  final bool isOn;
  final int brightness; // 1-15 (ESP32 scale)
  final int mode; // 0=warm, 1=white, 2=both
  final double temperature; // Kelvin value for UI display
  final DateTime lastUpdated;

  LampState({
    this.isOn = true,
    this.brightness = 8, // Default to mid-range
    this.mode = 2, // Default to both LEDs
    this.temperature = 4000.0, // Default to neutral
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  LampState copyWith({
    bool? isOn,
    int? brightness,
    int? mode,
    double? temperature,
    DateTime? lastUpdated,
  }) {
    return LampState(
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      mode: mode ?? this.mode,
      temperature: temperature ?? this.temperature,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  // Convert to Flutter UI values for compatibility
  double get flutterBrightness =>
      (brightness - 1) / 14.0; // Map 1-15 to 0.0-1.0

  double get flutterTemperature {
    // Map ESP32 modes to temperature values for UI
    switch (mode) {
      case 0:
        return 2800.0; // MODE_WARM
      case 1:
        return 5500.0; // MODE_WHITE
      case 2:
        return temperature; // MODE_BOTH - use stored temperature
      default:
        return 4000.0;
    }
  }

  // Create from ESP state
  factory LampState.fromEspState(Map<String, dynamic> espState) {
    final mode = espState['mode'] ?? 2;
    return LampState(
      isOn: espState['on'] ?? true,
      brightness: (espState['brightness'] ?? 8).clamp(1, 15),
      mode: mode,
      temperature: _temperatureFromMode(mode),
      lastUpdated: DateTime.now(),
    );
  }

  static double _temperatureFromMode(int mode) {
    switch (mode) {
      case 0:
        return 2800.0; // MODE_WARM
      case 1:
        return 5500.0; // MODE_WHITE
      case 2:
        return 4000.0; // MODE_BOTH - default neutral
      default:
        return 4000.0;
    }
  }

  // Create from Flutter UI values
  factory LampState.fromFlutterValues({
    required bool isOn,
    required double brightness, // 0.0-1.0
    required double temperature, // Kelvin
  }) {
    final espBrightness = ((brightness * 14) + 1).round().clamp(1, 15);
    final mode = _modeFromTemperature(temperature);

    return LampState(
      isOn: isOn,
      brightness: espBrightness,
      mode: mode,
      temperature: temperature,
      lastUpdated: DateTime.now(),
    );
  }

  static int _modeFromTemperature(double temperature) {
    if (temperature <= 3000) return 0; // MODE_WARM
    if (temperature >= 5000) return 1; // MODE_WHITE
    return 2; // MODE_BOTH
  }

  Map<String, dynamic> toJson() {
    return {
      'is_on': isOn ? 1 : 0,
      'brightness': brightness,
      'mode': mode,
      'temperature': temperature,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory LampState.fromJson(Map<String, dynamic> json) {
    return LampState(
      isOn: (json['is_on'] as int?) == 1,
      brightness: (json['brightness'] as int?) ?? 8,
      mode: (json['mode'] as int?) ?? 2,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 4000.0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_updated'] as int)
          : DateTime.now(),
    );
  }

  // Create table SQL for database
  static const String tableName = 'lamp_state';

  static const String createTableSql =
      '''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY,
      is_on INTEGER NOT NULL DEFAULT 1,
      brightness INTEGER NOT NULL DEFAULT 8,
      mode INTEGER NOT NULL DEFAULT 2,
      temperature REAL NOT NULL DEFAULT 4000.0,
      last_updated INTEGER NOT NULL
    );
  ''';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LampState &&
          runtimeType == other.runtimeType &&
          isOn == other.isOn &&
          brightness == other.brightness &&
          mode == other.mode &&
          temperature == other.temperature;

  @override
  int get hashCode =>
      isOn.hashCode ^
      brightness.hashCode ^
      mode.hashCode ^
      temperature.hashCode;

  @override
  String toString() {
    return 'LampState{isOn: $isOn, brightness: $brightness, mode: $mode, temperature: $temperature}';
  }
}
