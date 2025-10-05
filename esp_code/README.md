# ESP32 Firmware Secrets Setup

This firmware loads Wi-Fi credentials from a local `.env` file before every build. The credentials are converted into a generated header (`src/wifi_credentials.h`) that is **not** committed to Git, so the repository stays clean.

## Quick start

1. Copy `.env.example` to `.env` in this directory.
2. Fill in your real network values:
   ```
   WIFI_SSID=YourNetworkName
   WIFI_PASSWORD=YourNetworkPassword
   ```
3. Build or upload the firmware with PlatformIO (`pio run` / `pio run -t upload`).

The build will fail fast if the `.env` file is missing or the required keys are absent.

## Notes

- The generated file lives at `src/wifi_credentials.h` and is ignored by Git.
- Update `.env` whenever you need to flash a different network; rebuilding regenerates the header automatically.
