# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
# Run the app
flutter run

# Build for production
flutter build apk
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze

# Get dependencies
flutter pub get

# Clean build files
flutter clean
```

## Architecture Overview

This is a Flutter app that controls ESP32-based circadian lighting devices. The app connects to ESP32 devices via WebSocket over WiFi to control LED brightness and color temperature based on circadian rhythms.

### Core Architecture

- **main.dart**: Entry point with 3-tab navigation (Home, Routines, Settings)
- **Core Services**:
  - `EspConnection`: WebSocket communication with ESP32 devices via mDNS discovery
  - `DatabaseService`: SQLite + SharedPreferences for local data persistence
  - `EspSyncService`: Syncs app state with ESP32 device state
  - `SunriseSunsetManager`: Calculates and manages circadian light routines

### Key Models

- **LampState**: UI brightness (0.0-1.0) and temperature (2700K-6500K) values
- **EspState**: ESP32 device state (brightness: 1-15, mode: 0=warm/1=white/2=both)
- **Routine**: Scheduled lighting patterns with start/end times and gradual transitions
- **Alarm**: Wake-up alarms with gradual brightness ramp-up
- **UserSettings**: App preferences and configuration

### Data Flow

1. UI changes → LampState → EspSyncService → ESP32 via WebSocket
2. ESP32 state changes → EspConnection → UI updates
3. Routines/Alarms → SunriseSunsetManager → scheduled state changes
4. All state persisted in SQLite database

### ESP32 Communication

- Protocol: JSON over WebSocket
- Discovery: mDNS service discovery for `_circadian._tcp` services
- Commands: `{"brightness": 1-15, "mode": 0-2, "on": true/false}`
- ESP32 modes: 0=warm (2700K), 1=white (6500K), 2=both (4600K)

### Provisioning Flow

The app includes ESP32 WiFi provisioning via ESP SmartConfig:
- `ProvisioningScreen`: Guides users through device setup
- `esp_smartconfig` plugin: Handles SmartConfig protocol
- Device discovery after successful provisioning

### Database Schema

- **routines**: id, name, startTime, endTime, isEnabled, days, startBrightness, endBrightness, startTemperature, endTemperature
- **alarms**: id, name, time, isEnabled, days, duration, targetBrightness, targetTemperature
- **UserSettings**: stored in SharedPreferences

### State Management

- No formal state management framework - uses StatefulWidget with direct database/service calls
- EspConnection singleton maintains WebSocket connection state
- Database changes trigger UI rebuilds via setState()

## File Organization

- `lib/core/`: Core services and connection management
- `lib/models/`: Data models and state classes
- `lib/services/`: Business logic services
- `lib/screens/`: Main UI screens
- `lib/widgets/`: Reusable UI components
- `assets/models/`: 3D models for lamp visualization

## Testing Notes

The project currently has no test files setup. Use `flutter test` command but expect no tests to run until test files are created.