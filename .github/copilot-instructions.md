# Circadian Light Project - AI Assist## Critical Development Workflows

### Flutter Development
```ba## Key Integration Points

### Time Synchronization (Critical)
ESP32 requires accurate Auckland time for schedule execution:
- App sends UTC timestamp: `{ "type": "time_sync", "timestamp": <UTC_ms> }`
- ESP32 converts to Auckland time (UTC+13) and updates system clock
- Must sync before sending routines/alarms or they won't trigger correctly

### Schedule Data Structures
ESP32 stores schedules in fixed C structs:
```cpp
struct Routine {
  int id, start_hour, start_minute, end_hour, end_minute;
  int brightness;  // 1-15 scale
  int mode;        // 0=warm, 1=white, 2=both
  bool enabled;
};
```

### Flutter-ESP32 Value Mapping
- **Brightness**: Flutter 0.0-1.0 ↔ ESP32 1-15 (via `EspState.flutterBrightness`)
- **Temperature**: Flutter Kelvin ↔ ESP32 mode (≤3000K→warm, ≥5000K→white, else both)
- **Time**: Flutter `TimeOfDay` ↔ ESP32 hour/minute integers

## Environment Setup

### ESP32 Dependencies (platformio.ini)
```ini
lib_deps =
  ESP32Async/ESPAsyncWebServer@^3.7.7  # WebSocket server
  bblanchon/ArduinoJson@^7.4.1         # JSON handling
  mathertel/RotaryEncoder@^1.4.3       # Hardware controls
```

### Flutter Dependencies (pubspec.yaml)
# Circadian Light Project - AI Assistant Guide

## Project Overview
This is a **dual-architecture project** consisting of a Flutter mobile app (`circadian_light/`) and ESP32 embedded firmware (`esp_code/`) that work together to create a smart light with automated scheduling. The ESP32 can operate independently using synced schedules.

## Top-level layout
- Firmware: `esp_code/` (PlatformIO, Arduino framework)
- App: `circadian_light/` (Flutter)

## Architecture Overview

### Flutter App Pattern
- **Singleton services** with `.I` accessor: `EspConnection.I`, `EspSyncService.I`, `DatabaseService.instance`
- **ChangeNotifier controllers**: `RoutineCore` for UI state management
- **SQLite persistence**: Local-first with ESP32 sync on success
- **WebSocket communication**: Auto-reconnecting with mDNS discovery

### ESP32 Firmware
- **AsyncWebServer** with WebSocket at `ws://circadian-light.local/ws`
- **Independent scheduling**: Fixed arrays for routines (`MAX_ROUTINES=10`) and alarms (`MAX_ALARMS=5`)
- **Hardware controls**: Rotary encoder (brightness) + button (on/off, mode cycling)
- **Timezone**: Hardcoded Auckland/NZDT (UTC+13)

## Communication Protocol

### Basic Control (Real-time)
- App → Device: `{ "brightness": 1..15, "mode": 0..2, "on": true|false }`
  - `brightness`: 1-15 scale (minimum 1 when on, 0 when off)
  - `mode`: 0=warm, 1=white, 2=both
- Device → App: `{ "state": { brightness, mode, on } }` on connect and hardware changes

### Schedule Sync (Structured)
- Routine sync: `{ "type": "routine_sync", "action": "upsert|delete", "data": {...} }`
- Alarm sync: `{ "type": "alarm_sync", "action": "upsert|delete", "data": {...} }`
- Time sync: `{ "type": "time_sync", "timestamp": <UTC_milliseconds> }`
- Full sync: `{ "type": "full_sync", "routines": [...], "alarms": [...] }`

## Critical Development Workflows

### Flutter Development
```bash
cd circadian_light/
flutter run --device-id=<DEVICE_ID>  # Use --profile for performance testing
flutter build ios --release           # iOS release build
```

### ESP32 Development
```bash
cd esp_code/
# Use VS Code task "PlatformIO Upload" or:
.venv/bin/platformio run --target upload
# Monitor serial output:
.venv/bin/platformio device monitor
```

## Device Control Logic
- **LED channels**: Active-low PWM (high duty = off). See `applyOutput()` in `main.cpp`
- **Brightness scale**: 1-15 when on (minimum 1), 0 when off. Maps to 4-bit LEDC resolution
- **Physical controls**:
  - Rotary encoder: Adjusts brightness, sends state updates to app
  - Button: Single-click = on/off toggle, double-click = mode cycling (warm→white→both)
- **Schedule system**: ESP32 preserves current state when routines/alarms activate, restores when they end

## App Architecture Patterns

### Singleton Service Pattern
All core services use singleton with `.I` accessor:
```dart
EspConnection.I.connect()
EspSyncService.I.syncRoutine(routine)
DatabaseService.instance.saveRoutine(routine)
```

### Database-to-ESP32 Sync Flow
1. UI saves to `RoutineCore` (ChangeNotifier)
2. `RoutineCore` calls `DatabaseService.saveRoutine()`
3. `DatabaseService` saves to SQLite → triggers `EspSyncService`
4. `EspSyncService` sends WebSocket command if ESP32 connected
5. ESP32 stores in local arrays and sends acknowledgment

### Error Handling Pattern (Offline-First)
Database operations continue even if ESP32 sync fails:
```dart
try {
  await EspSyncService.I.syncRoutine(routineWithId);
} catch (e) {
  _logger.warning('Failed to sync routine to ESP32: $e');
  // Don't fail the save operation
}
```

### State Management
- **UI state**: `RoutineCore` extends ChangeNotifier
- **ESP32 state**: `EspConnection.I.stateUpdates` stream
- **Persistence**: SQLite via `DatabaseService` with automatic ESP32 sync

## Key Integration Points

### Time Synchronization (Critical)
ESP32 requires accurate Auckland time for schedule execution:
- App sends UTC timestamp: `{ "type": "time_sync", "timestamp": <UTC_ms> }`
- ESP32 converts to Auckland time (UTC+13) and updates system clock
- Must sync before sending routines/alarms or they won't trigger correctly

### Schedule Data Structures
ESP32 stores schedules in fixed C structs:
```cpp
struct Routine {
  int id, start_hour, start_minute, end_hour, end_minute;
  int brightness;  // 1-15 scale
  int mode;        // 0=warm, 1=white, 2=both
  bool enabled;
};
```

### Flutter-ESP32 Value Mapping
- **Brightness**: Flutter 0.0-1.0 ↔ ESP32 1-15 (via `EspState.flutterBrightness`)
- **Temperature**: Flutter Kelvin ↔ ESP32 mode (≤3000K→warm, ≥5000K→white, else both)
- **Time**: Flutter `TimeOfDay` ↔ ESP32 hour/minute integers

## Environment Setup

### ESP32 Dependencies (platformio.ini)
```ini
lib_deps =
  ESP32Async/ESPAsyncWebServer@^3.7.7  # WebSocket server
  bblanchon/ArduinoJson@^7.4.1         # JSON handling
  mathertel/RotaryEncoder@^1.4.3       # Hardware controls
```

### Flutter Dependencies (pubspec.yaml)
```yaml
dependencies:
  web_socket_channel: ^3.0.3    # ESP32 communication
  multicast_dns: ^0.3.2         # ESP32 discovery  
  sqflite: ^2.3.3+1             # Local database
  flutter_3d_controller: ^2.2.0 # 3D lamp visualization
```

## Common Debugging Patterns

### ESP32 Connection Issues
1. **mDNS resolution**: ESP32 advertises as `circadian-light.local`
2. **WebSocket endpoint**: Verify `ws://<ESP32_IP>/ws` accessibility
3. **Serial monitor**: ESP32 logs all WebSocket messages at 115200 baud
4. **iOS mDNS**: Uses system Bonjour instead of multicast to avoid permission issues

### Schedule Sync Debugging
1. **Time sync first**: ESP32 must have accurate Auckland time before schedules work
2. **JSON format**: Verify routine/alarm data matches ESP32 struct fields exactly
3. **Sync responses**: ESP32 sends acknowledgment messages like `routine_sync_response`
4. **Schedule limits**: ESP32 has fixed limits (`MAX_ROUTINES=10`, `MAX_ALARMS=5`)

### Database Issues
- Current schema version: 1 (in `DatabaseService._databaseVersion`)
- **Migration pattern**: Increment version, implement in `_upgradeDatabase()`
- **Table recovery**: `_ensureTablesExist()` handles missing tables gracefully

## Key File References
- **ESP32 main**: `esp_code/src/main.cpp` (active firmware entry point)
- **ESP32 config**: `esp_code/platformio.ini` (ports, dependencies)
- **Flutter connection**: `lib/core/esp_connection.dart` (WebSocket, mDNS)
- **Schedule sync**: `lib/services/esp_sync_service.dart` (routine/alarm sync)
- **Database**: `lib/services/database_service.dart` (SQLite operations)
- **UI controllers**: `lib/core/routine_core.dart` (ChangeNotifier pattern)

## Extension Guidelines
- **Protocol changes**: Update both ESP32 `onWSMsg()` and Flutter `EspConnection`
- **New schedules**: Respect ESP32 memory limits and struct definitions
- **Database schema**: Always implement migration path for existing data
- **Error handling**: Maintain offline-first pattern - don't fail operations on sync errorsadian_light/
flutter run --device-id=<DEVICE_ID>  # Use --profile for performance testing
flutter build ios --release           # iOS release build
```

### ESP32 Development
```bash
cd esp_code/
# Use VS Code task "PlatformIO Upload" or:
.venv/bin/platformio run --target upload
# Monitor serial output:
.venv/bin/platformio device monitor
```

## Device Control Logic
- **LED channels**: Active-low PWM (high duty = off). See `applyOutput()` in `main.cpp`
- **Brightness scale**: 1-15 when on (minimum 1), 0 when off. Maps to 4-bit LEDC resolution
- **Physical controls**:
  - Rotary encoder: Adjusts brightness, sends state updates to app
  - Button: Single-click = on/off toggle, double-click = mode cycling (warm→white→both)
- **Schedule system**: ESP32 preserves current state when routines/alarms activate, restores when they endide

## Project Overview
This is a **dual-architecture project** consisting of a Flutter mobile app (`circadian_light/`) and ESP32 embedded firmware (`esp_code/`) that work together to create a smart light with automated scheduling. The ESP32 can operate independently using synced schedules.

## Top-level layout
- Firmware: `esp_code/` (PlatformIO, Arduino framework)
- App: `circadian_light/` (Flutter)

## Architecture Overview

### Flutter App Pattern
- **Singleton services** with `.I` accessor: `EspConnection.I`, `EspSyncService.I`, `DatabaseService.instance`
- **ChangeNotifier controllers**: `RoutineCore` for UI state management
- **SQLite persistence**: Local-first with ESP32 sync on success
- **WebSocket communication**: Auto-reconnecting with mDNS discovery

### ESP32 Firmware
- **AsyncWebServer** with WebSocket at `ws://circadian-light.local/ws`
- **Independent scheduling**: Fixed arrays for routines (`MAX_ROUTINES=10`) and alarms (`MAX_ALARMS=5`)
- **Hardware controls**: Rotary encoder (brightness) + button (on/off, mode cycling)
- **Timezone**: Hardcoded Auckland/NZDT (UTC+13)

## Communication Protocol

### Basic Control (Real-time)
- App → Device: `{ "brightness": 1..15, "mode": 0..2, "on": true|false }`
  - `brightness`: 1-15 scale (minimum 1 when on, 0 when off)
  - `mode`: 0=warm, 1=white, 2=both
- Device → App: `{ "state": { brightness, mode, on } }` on connect and hardware changes

### Schedule Sync (Structured)
- Routine sync: `{ "type": "routine_sync", "action": "upsert|delete", "data": {...} }`
- Alarm sync: `{ "type": "alarm_sync", "action": "upsert|delete", "data": {...} }`
- Time sync: `{ "type": "time_sync", "timestamp": <UTC_milliseconds> }`
- Full sync: `{ "type": "full_sync", "routines": [...], "alarms": [...] }`

## Device control logic (why it’s shaped this way)
- LED channels are active‑low; “off” = high duty. Firmware inverts brightness when ON and drives both channels for mode=2. See `applyOutput()` in `main_test2.cpp`.
- Brightness scale 0–15 intentionally maps to LEDC 4‑bit resolution for smooth, discrete steps without quantization surprises.
- Physical inputs:
  - Rotary encoder increments master brightness (0–15) and pushes a `state` update.
  - Button: single‑click toggles `on`, double‑click cycles `mode`. Debounced and polarity‑agnostic. See button handling in `loop()`.

## App Architecture Patterns

### Singleton Service Pattern
All core services use singleton with `.I` accessor:
```dart
EspConnection.I.connect()
EspSyncService.I.syncRoutine(routine)
DatabaseService.instance.saveRoutine(routine)
```

### Database-to-ESP32 Sync Flow
1. UI saves to `RoutineCore` (ChangeNotifier)
2. `RoutineCore` calls `DatabaseService.saveRoutine()`
3. `DatabaseService` saves to SQLite → triggers `EspSyncService`
4. `EspSyncService` sends WebSocket command if ESP32 connected
5. ESP32 stores in local arrays and sends acknowledgment

### Error Handling Pattern (Offline-First)
Database operations continue even if ESP32 sync fails:
```dart
try {
  await EspSyncService.I.syncRoutine(routineWithId);
} catch (e) {
  _logger.warning('Failed to sync routine to ESP32: $e');
  // Don't fail the save operation
}
```

### State Management
- **UI state**: `RoutineCore` extends ChangeNotifier
- **ESP32 state**: `EspConnection.I.stateUpdates` stream
- **Persistence**: SQLite via `DatabaseService` with automatic ESP32 sync

## Build, run, and debug
- Firmware (ESP32):
  - VS Code task: “PlatformIO Upload” (uses `esp_code/.venv/bin/platformio run --target upload`).
  - Edit ports in `esp_code/platformio.ini` (`upload_port`, `monitor_port`), default `115200` baud.
  - Active firmware entry point: `esp_code/src/main_test2.cpp`. `main.cpp` contains older, commented code for reference.
  - Tip: Use Serial at 115200 to see WebSocket connect/disconnect, JSON RX, and `applyOutput()` diagnostics.
- App (Flutter):
  - Dependencies in `pubspec.yaml` include `web_socket_channel`, `multicast_dns`, `esp_smartconfig`, and `flutter_3d_controller` for the GLB model in `assets/models/`.
  - SmartConfig provisioning UI lives in `lib/core/provisioning_screen.dart` (EspTouch V2). iOS Simulator lacks Wi‑Fi, so provisioning is disabled there.
  - Initial connection starts in `main.dart` via `EspConnection.I.connect()`.

## Patterns to follow when extending
- Prefer sending minimal diffs (only the key you change); firmware will merge into current state.
- Don’t assume echo; update local UI immediately on user actions, and treat `stateUpdates` as authoritative when hardware changes happen.
- If adding new protocol fields, update:
  - Firmware WebSocket handler in `onWSMsg` and `sendStateUpdate()` shape.
  - App: `EspState`, `EspConnection.send(...)` helpers, and any listening UI.
- Keep the 0–15 brightness contract unless you also change LEDC resolution and inversion logic.

## Useful file pointers
- Firmware: `esp_code/src/main_test2.cpp`, `esp_code/platformio.ini`
- App core: `lib/core/esp_connection.dart`, `lib/core/sunrise_sunset_manager.dart`
- App UI: `lib/screens/home.dart`, `lib/screens/settings.dart`, `lib/screens/routines.dart`

## Caveats
- Current firmware on this branch connects via hard‑coded SSID/PASS in `main_test2.cpp`. The app’s SmartConfig screen is present but firmware must implement provisioning/Wi‑Fi‑manager to use it end‑to‑end.
