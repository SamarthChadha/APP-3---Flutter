// Model representing user preferences and app settings

class UserSettings {
  final bool sunriseSunsetEnabled;
  final String? lastConnectedDeviceId;
  final String? deviceName;
  final Map<String, dynamic> espConnectionSettings;
  final bool firstTimeSetup;
  final DateTime lastUpdated;

  UserSettings({
    this.sunriseSunsetEnabled = false,
    this.lastConnectedDeviceId,
    this.deviceName,
    this.espConnectionSettings = const {},
    this.firstTimeSetup = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  UserSettings copyWith({
    bool? sunriseSunsetEnabled,
    String? lastConnectedDeviceId,
    String? deviceName,
    Map<String, dynamic>? espConnectionSettings,
    bool? firstTimeSetup,
    DateTime? lastUpdated,
  }) {
    return UserSettings(
      sunriseSunsetEnabled: sunriseSunsetEnabled ?? this.sunriseSunsetEnabled,
      lastConnectedDeviceId:
          lastConnectedDeviceId ?? this.lastConnectedDeviceId,
      deviceName: deviceName ?? this.deviceName,
      espConnectionSettings:
          espConnectionSettings ?? this.espConnectionSettings,
      firstTimeSetup: firstTimeSetup ?? this.firstTimeSetup,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sunrise_sunset_enabled': sunriseSunsetEnabled,
      'last_connected_device_id': lastConnectedDeviceId,
      'device_name': deviceName,
      'esp_connection_settings': espConnectionSettings,
      'first_time_setup': firstTimeSetup,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      sunriseSunsetEnabled: json['sunrise_sunset_enabled'] as bool? ?? false,
      lastConnectedDeviceId: json['last_connected_device_id'] as String?,
      deviceName: json['device_name'] as String?,
      espConnectionSettings:
          json['esp_connection_settings'] as Map<String, dynamic>? ?? {},
      firstTimeSetup: json['first_time_setup'] as bool? ?? true,
      lastUpdated: json['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_updated'] as int)
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          sunriseSunsetEnabled == other.sunriseSunsetEnabled &&
          lastConnectedDeviceId == other.lastConnectedDeviceId &&
          deviceName == other.deviceName &&
          firstTimeSetup == other.firstTimeSetup;

  @override
  int get hashCode =>
      sunriseSunsetEnabled.hashCode ^
      lastConnectedDeviceId.hashCode ^
      deviceName.hashCode ^
      firstTimeSetup.hashCode;

  @override
  String toString() {
    return 'UserSettings{sunriseSunsetEnabled: $sunriseSunsetEnabled, '
        'deviceName: $deviceName, firstTimeSetup: $firstTimeSetup}';
  }
}
