# AI agent quickstart for this repo

This workspace contains a Flutter mobile app and an ESP32 firmware that talk over a WebSocket using a tiny JSON protocol.

## Top-level layout
- Firmware: `esp_code/` (PlatformIO, Arduino framework)
- App: `circadian_light/` (Flutter)

## How things talk (architecture)
- Device hosts an AsyncWebServer with a WebSocket at `ws://circadian-light.local/ws` and advertises `_ws._tcp` via mDNS. See `esp_code/src/main_test2.cpp`.
- App resolves the device via mDNS and keeps a reconnecting WebSocket. See `lib/core/esp_connection.dart`.
- JSON protocol (current, preferred):
  - App → Device: `{ "brightness": 0..15, "mode": 0..2, "on": true|false }`
    - `brightness` is 4‑bit (0–15) by design; firmware uses 4‑bit LEDC to match.
    - `mode`: 0 = warm, 1 = white, 2 = both.
  - Device → App: `{ "state": { brightness, mode, on } }` on connect and whenever hardware changes occur (rotary/button). Firmware does not echo state immediately when the app sets values to avoid loops.
- Legacy (testing) keys exist: `a`/`b` for direct PWM writes. Prefer the protocol above; helpers still exist in `EspConnection.setA/setB` for diagnostics.

## Device control logic (why it’s shaped this way)
- LED channels are active‑low; “off” = high duty. Firmware inverts brightness when ON and drives both channels for mode=2. See `applyOutput()` in `main_test2.cpp`.
- Brightness scale 0–15 intentionally maps to LEDC 4‑bit resolution for smooth, discrete steps without quantization surprises.
- Physical inputs:
  - Rotary encoder increments master brightness (0–15) and pushes a `state` update.
  - Button: single‑click toggles `on`, double‑click cycles `mode`. Debounced and polarity‑agnostic. See button handling in `loop()`.

## App conventions and flows
- `EspConnection` owns connection state, mDNS resolving, and streams:
  - `connection` (bool) and `stateUpdates` (EspState). UI listens to these in `HomeScreen`.
  - On iOS, it relies on system Bonjour for `.local` hostnames to avoid multicast join errors; other platforms use `multicast_dns`.
- UI → Device mapping:
  - Brightness slider maps to 0–15 with small debounce timers before sending. See `HomeScreen._mapBrightnessTo15` and `Timer` usage.
  - Temperature slider maps K→mode: <=3000K warm, >=5000K white, else both.
- Sunrise/Sunset automation (`lib/core/sunrise_sunset_manager.dart`):
  - Minute timer drives daytime transitions; when enabled, manual routines are effectively disabled in UI (`RoutinesScreen`).

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
