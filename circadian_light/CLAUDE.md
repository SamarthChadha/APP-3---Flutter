# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter app for controlling circadian lighting systems via ESP32 devices. The app manages lighting routines, alarms, and real-time device communication to automatically adjust light color temperature and brightness throughout the day.

## Common Commands

### Development
```bash
# Run the app in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>

# Hot reload (during development)
# Press 'r' in terminal or save files with hot reload enabled

# Build for release
flutter build apk --release
flutter build ios --release
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Check specific file
flutter analyze lib/path/to/file.dart

# Format code
flutter format lib/

# Clean build artifacts
flutter clean
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

## Architecture Overview

### Core Architecture Pattern
- **MVC-like pattern**: Screens (Views) → Core Controllers → Services → Models
- **State Management**: ChangeNotifier pattern for reactive UI updates
- **Data Persistence**: SQLite for structured data + SharedPreferences for simple settings

### Key Components

#### Core Layer (`lib/core/`)
- **RoutineCore**: Central controller managing routines and alarms business logic
- **EspConnection**: Singleton managing WebSocket communication with ESP32 devices
- **SunriseSunsetManager**: Handles automatic sunrise/sunset lighting synchronization
- **ConnectionManager**: Manages network discovery and device provisioning

#### Services Layer (`lib/services/`)
- **DatabaseService**: SQLite operations for routines, alarms, and settings persistence
- **EspSyncService**: Bidirectional synchronization between app and ESP32 devices

#### Models (`lib/models/`)
- **Routine**: Time-based lighting schedules with color temperature and brightness
- **Alarm**: Wake-up light sequences with gradual brightness ramping
- **LampState**: Current device state representation
- **UserSettings**: App configuration and preferences

#### Screens (`lib/screens/`)
- **HomeScreen**: Device control interface with 3D lamp visualization
- **RoutinesScreen**: CRUD operations for routines and alarms with undo functionality
- **SettingsScreen**: App configuration and device management

#### Widgets (`lib/widgets/`)
- **RoutineCard/AlarmCard**: Swipe-to-delete cards with undo SnackBar
- **NeumorphicSlider**: Custom slider components for brightness/temperature control
- **TimePickerSheet**: Reusable time selection interface

### Data Flow
1. **UI Interaction** → Screen components
2. **Business Logic** → Core controllers (RoutineCore, etc.)
3. **Persistence** → DatabaseService (SQLite) or SharedPreferences
4. **Device Sync** → EspSyncService → EspConnection (WebSocket)
5. **State Updates** → ChangeNotifier → UI rebuilds

### ESP32 Integration
- **Discovery**: mDNS-based device discovery on local network
- **Communication**: WebSocket for real-time bidirectional communication
- **State Sync**: Automatic synchronization of routines, alarms, and manual controls
- **Provisioning**: Wi-Fi setup and device pairing flow

### Key Design Patterns
- **Singleton Pattern**: EspConnection, DatabaseService (accessed via `db` global)
- **Observer Pattern**: ChangeNotifier for reactive state management
- **Repository Pattern**: DatabaseService abstracts data persistence
- **Command Pattern**: ESP message structure for device communication

### Database Schema
- **routines**: Scheduled lighting programs
- **alarms**: Wake-up sequences
- **lamp_states**: Device state snapshots
- **user_settings**: App preferences (stored in SharedPreferences)

### Error Handling
- **Graceful degradation**: App functions without ESP32 connection
- **User feedback**: SnackBar notifications for errors and confirmations
- **Logging**: Comprehensive logging via `logging` package for debugging
- **Undo functionality**: Recent deletions can be undone via SnackBar actions

## Development Notes

### Code Conventions
- Follow existing neumorphic design patterns for UI consistency
- Use `_logger` static fields for component-specific logging
- Implement proper dispose() methods for controllers and animations
- Prefer `late final` for controllers and services
- Use `copyWith()` pattern for immutable model updates

### Testing ESP32 Integration
- Ensure ESP32 device is on same network for mDNS discovery
- Use device logs for WebSocket communication debugging
- Test offline functionality (app should work without device connection)

### UI/UX Patterns
- Swipe-to-delete with undo SnackBar for all list items
- Neumorphic design with consistent shadows and gradients
- Material 3 design system with custom yellow accent color (#FFC049)
- Bottom sheet modals for creation/editing flows