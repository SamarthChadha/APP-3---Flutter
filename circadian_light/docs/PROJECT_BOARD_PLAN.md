# Circadian Light – Project Board Plan

Based on analysis of local Git branches and commit history. Ready to import into GitHub Project “Circadian Light App”.

Repo: SamarthChadha/APP-3---Flutter  
Analyzed: 2025-09-04

## Snapshot
- Recent: slider/home UX, button layout, device-state sync (Sep 2)
- Features: sunrise/sunset sync + gradual CCT (Aug 28)
- Connectivity: connection-test merged (Aug 27)
- Provisioning: SmartConfig + Wi‑Fi manager experiment branches
- Firmware: 8→4‑bit LED, encoder simplification

Active branches: `Provisioning-Screen`, `Wifi-Setup`, `testing-sunrise-sunset-routines`.

## Board items to create (Status/Iteration suggested)
In progress (Iteration: @current)
1) App: Provisioning screen + flow integration — Labels: flutter, networking, provisioning — Est: 3
2) Firmware: Async Wi‑Fi manager + config persistence — Labels: esp32, firmware, networking — Est: 3
3) Routines: Sunrise/Sunset validation + parameters — Labels: flutter, feature — Est: 2

To‑Start
4) Connection lifecycle + offline UX — Labels: flutter, reliability — Est: 2
5) App ↔ ESP command protocol v1 — Labels: protocol, docs, esp32 — Est: 2
6) Real‑time controls: throttle/debounce + haptics — Labels: flutter, performance — Est: 1
7) Settings screen — Labels: flutter, ui — Est: 3
8) Firmware: 4‑bit LED mapping + gamma/ramping — Labels: esp32, firmware — Est: 2
9) Schedule storage in NVS — Labels: esp32, firmware — Est: 3
10) Device discovery + reconnect — Labels: networking, esp32, flutter — Est: 2
11) CI: Flutter analyze/tests + PlatformIO build on PR — Labels: ci, testing — Est: 2
12) Telemetry/logging — Labels: tooling, reliability — Est: 1

Done (recent)
- Sliders rework + state sync; Sunrise/Sunset with gradual CCT; initial connection test.

## How to import quickly
- Use docs/project_items.csv (below) with GitHub Project “Add items → Add from CSV”, map columns to your fields (Status, Iteration, Estimate, Labels).
