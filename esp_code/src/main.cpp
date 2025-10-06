#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>
#include <time.h>

#include "wifi_credentials.h"

const char* SSID     = wifi_credentials::SSID;
const char* PASSWORD = wifi_credentials::PASSWORD;


#define LED_BUILTIN 2   // builtin LED (GPIO2)
#define LED_A_PIN   16  // first LED group PWM (warm)
#define LED_B_PIN   17  // second LED group PWM (white)

#define ROTARY_DT  32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

const char* ESP_IP = "10.210.232.242";   // update if the ESP32 reboots with a new IP
const char* WS_URL = "ws://10.210.232.242/ws";

// Time zone configuration for Auckland, New Zealand
const char* ntpServer = "pool.ntp.org";
// POSIX timezone string for New Zealand (automatically handles NZST/NZDT transitions)
// NZST-12: Standard time UTC+12, NZDT: Daylight time UTC+13
// M9.5.0: DST starts last Sunday of September, M4.1.0: DST ends first Sunday of April
const char* timezone = "NZST-12NZDT,M9.5.0,M4.1.0";

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");

RotaryEncoder encoder(ROTARY_DT, ROTARY_CLK);

// ===== Schedule Data Structures =====
struct Routine {
  int id;
  bool enabled;
  int start_hour, start_minute;
  int end_hour, end_minute;
  int brightness;  // 0-15
  int mode;        // 0=warm, 1=white, 2=both
};

struct Alarm {
  int id;
  bool enabled;
  int wake_hour, wake_minute;
  int start_hour, start_minute;
  int duration_minutes;
};

// Storage for routines and alarms (limited for ESP32 memory)
const int MAX_ROUTINES = 10;
const int MAX_ALARMS = 5;
Routine routines[MAX_ROUTINES];
Alarm alarms[MAX_ALARMS];
int routine_count = 0;
int alarm_count = 0;

// Schedule tracking
unsigned long lastScheduleCheck = 0;
const unsigned long SCHEDULE_CHECK_INTERVAL = 1000; // Check every second for precise timing

// ===== New simplified control state =====
enum Mode { MODE_WARM = 0, MODE_WHITE = 1, MODE_BOTH = 2 };

// ===== Routine state tracking =====
bool routineActive = false;          // Is a routine currently running?
bool wasOffBeforeRoutine = false;    // Was the lamp off before routine started?
int activeRoutineId = -1;            // ID of currently active routine
int originalBrightness = 8;          // Brightness before routine
Mode originalMode = MODE_BOTH;       // Mode before routine
bool originalIsOn = true;            // On/off state before routine
int lastRoutineMinute = -1;          // Track last minute routine was checked to prevent repeated triggers

// ===== Alarm state tracking =====
bool alarmActive = false;            // Is an alarm currently running?
bool wasOffBeforeAlarm = false;      // Was the lamp off before alarm started?
int activeAlarmId = -1;              // ID of currently active alarm
int alarmOriginalBrightness = 8;     // Brightness before alarm
Mode alarmOriginalMode = MODE_BOTH;  // Mode before alarm
bool alarmOriginalIsOn = true;       // On/off state before alarm
int lastAlarmMinute = -1;            // Track last minute alarm was checked

Mode mode = MODE_BOTH;                 // double-click cycles this
int brightness = 0;                  // 0-15 master brightness (independent of on/off & mode)
bool isOn = true;                      // single-click toggles this

bool routineSuppressed = false;
Routine suppressedRoutine = {};
bool alarmSuppressed = false;
Alarm suppressedAlarm = {};

bool sunSyncActive = false;
bool sunSyncDisabledByHardware = false;

unsigned long lastClickReleaseTime = 0;

// Button click state (robust, polarity-agnostic)
uint8_t clickCount = 0;                // 1 = single (after timeout), 2 = double
unsigned long firstClickTime = 0;      // time of first click
const uint16_t DEBOUNCE_MS     = 35;   // debounce time (ms)
const bool BUTTON_ACTIVE_LOW   = true; // set false if wired active-high
const uint16_t MULTI_CLICK_WINDOW_MS = 600; // grouping window for single/double/triple click (ms)
const uint8_t OVERRIDE_BLINK_COUNT   = 2;
const uint16_t OVERRIDE_BLINK_INTERVAL_MS = 150;

// ===== Forward Declarations =====
void handleRoutineSync(JsonDocument& doc);
void handleAlarmSync(JsonDocument& doc);
void handleFullSync(JsonDocument& doc);
void handleTimeSync(JsonDocument& doc);
void sendSyncResponse(const char* type, bool success, const char* message);
void handleSunSyncState(bool active, const char* source);
void handleTripleClick();
bool isManualControlLocked();
Routine* findRoutineById(int id);
Alarm* findAlarmById(int id);
bool isWithinTimeRange(int startHour, int startMinute, int endHour, int endMinute, int currentTime);
void updateSuppressionWindows(int currentTime);
void blinkLamp(uint8_t count, uint16_t intervalMs);
void broadcastOverrideEvent(const char* source, bool routineWasActive, bool alarmWasActive, bool sunSyncWasActive);
void sendSunSyncState(bool active, const char* source);

// ===== Helpers =====
void sendStateUpdate() {
  // Send current state to all connected WebSocket clients
  JsonDocument doc;
  JsonObject state = doc["state"].to<JsonObject>();
  state["brightness"] = brightness;
  state["mode"] = (int)mode;
  state["on"] = isOn;
  state["routine_active"] = routineActive;
  state["alarm_active"] = alarmActive;
  state["sun_sync_active"] = sunSyncActive;
  state["routine_suppressed"] = routineSuppressed;
  state["alarm_suppressed"] = alarmSuppressed;
  state["sun_sync_disabled_by_hw"] = sunSyncDisabledByHardware;
  state["manual_control_locked"] = isManualControlLocked();
  
  String jsonString;
  serializeJson(doc, jsonString);
  ws.textAll(jsonString);
  
  Serial.printf("Sent state update: %s\n", jsonString.c_str());
}

void applyOutput() {
  int ch0 = 15;
  int ch1 = 15;

  if (!isOn) {
    // When OFF: force both channels to 15 (inverted logic - high PWM = off)
    ledcWrite(0, ch0);
    ledcWrite(1, ch1);
    Serial.printf("applyOutput: isOn=%d mode=%d brightness=%d -> ch0=%d ch1=%d (OFF)\n",
                  (int)isOn, (int)mode, brightness, ch0, ch1);
    return;
  }

  // When ON: ensure minimum brightness is 1, compute channel values based on mode
  int safeBrightness = max(1, brightness); // Ensure minimum brightness of 1 when on
  // Invert brightness: 1 becomes 14, 15 becomes 0 (for correct LED behavior)
  int invertedBrightness = 15 - safeBrightness;
  
  switch (mode) {
    case MODE_WARM:   // mode 0
      ch0 = invertedBrightness; // warm channel active
      ch1 = 15;                 // white channel off (high PWM = off)
      break;
    case MODE_WHITE:  // mode 1
      ch0 = 15;                 // warm channel off (high PWM = off)
      ch1 = invertedBrightness; // white channel active
      break;
    case MODE_BOTH:   // mode 2
    default:
      ch0 = invertedBrightness; // both channels active
      ch1 = invertedBrightness;
      break;
  }

  ledcWrite(0, ch0);
  ledcWrite(1, ch1);
  Serial.printf("applyOutput: isOn=%d mode=%d brightness=%d safeBrightness=%d inverted=%d -> ch0=%d ch1=%d\n",
                (int)isOn, (int)mode, brightness, safeBrightness, invertedBrightness, ch0, ch1);
}

void onWSMsg(AsyncWebSocket *ws, AsyncWebSocketClient *client,
             AwsEventType type, void *arg, uint8_t *data, size_t len) {
  // --- Debug: log connect / disconnect ---
  if (type == WS_EVT_CONNECT) {
    Serial.printf("WebSocket client #%u connected\n", client->id());
    // Send current state to newly connected client
    sendStateUpdate();
    return;                         // nothing else to do
  }
  if (type == WS_EVT_DISCONNECT) {
    Serial.printf("WebSocket client #%u disconnected\n", client->id());
    return;
  }
  // ---------------------------------------
  if (type != WS_EVT_DATA) return;
  AwsFrameInfo *info = (AwsFrameInfo*)arg;
  if (!info->final || info->opcode != WS_TEXT) return;

  // Debug: print raw incoming payload
  String payload = String((const char*)data, len);
  Serial.printf("WS RX raw: %s\n", payload.c_str());

  JsonDocument doc;           // ArduinoJson v7 – elastic capacity
  DeserializationError err = deserializeJson(doc, data, len);
  if (err) {
    Serial.printf("WS JSON parse error: %s\n", err.c_str());
    return;
  }

  // Handle WebSocket commands that respect the button control system
  bool recognized = false;
  bool stateChanged = false;
  if (doc["brightness"].is<int>()) {    // brightness control from app
    int newBrightness = constrain(doc["brightness"].as<int>(), 0, 15);
    
    // If lamp is on, enforce minimum brightness of 1
    if (isOn && newBrightness < 1) {
      newBrightness = 1;
    }
    
    if (newBrightness != brightness) {
      brightness = newBrightness;
      stateChanged = true;
      Serial.printf("WebSocket: brightness -> %d (enforced min for isOn=%s)\n", 
                    brightness, isOn ? "true" : "false");
    }
    recognized = true;
  }
  if (doc["mode"].is<int>()) {    // mode control from app
    int newMode = constrain(doc["mode"].as<int>(), 0, 2);
    if ((Mode)newMode != mode) {
      mode = (Mode)newMode;
      stateChanged = true;
      Serial.printf("WebSocket: mode -> %d (0=WARM,1=WHITE,2=BOTH)\n", newMode);
    }
    recognized = true;
  }
  if (doc["on"].is<bool>()) {    // on/off control from app
    bool newIsOn = doc["on"].as<bool>();
    if (newIsOn != isOn) {
      isOn = newIsOn;
      stateChanged = true;
      Serial.printf("WebSocket: isOn -> %s\n", isOn ? "ON" : "OFF");
    }
    recognized = true;
  }

  // Handle state request from app (when reconnecting)
  if (doc["request_state"].is<bool>() && doc["request_state"].as<bool>()) {
    sendStateUpdate();
    Serial.println("WebSocket: sent current state on request");
    recognized = true;
  }

  // Handle sync messages from app
  if (doc["type"].is<const char*>()) {
    const char* msgType = doc["type"];
    
    if (strcmp(msgType, "routine_sync") == 0) {
      handleRoutineSync(doc);
      recognized = true;
    }
    else if (strcmp(msgType, "alarm_sync") == 0) {
      handleAlarmSync(doc);
      recognized = true;
    }
    else if (strcmp(msgType, "full_sync") == 0) {
      handleFullSync(doc);
      recognized = true;
    }
    else if (strcmp(msgType, "time_sync") == 0) {
      handleTimeSync(doc);
      recognized = true;
    }
    else if (strcmp(msgType, "sun_sync_state") == 0) {
      bool active = doc["active"].is<bool>() ? doc["active"].as<bool>() : false;
      const char* source = doc["source"].is<const char*>() ? doc["source"].as<const char*>() : "app";
      handleSunSyncState(active, source);
      recognized = true;
    }
  }

  if (stateChanged) {
    applyOutput();
    // Don't send state update back since this change came from the app
  }

  if (!recognized) {
    Serial.println("WS RX: no recognized keys in payload");
  }
}

// ===== Schedule Management Functions =====
void handleRoutineSync(JsonDocument& doc) {
  const char* action = doc["action"];
  
  if (strcmp(action, "upsert") == 0) {
    JsonObject data = doc["data"];
    int id = data["id"];
    
    // Find existing routine or add new one
    int index = -1;
    for (int i = 0; i < routine_count; i++) {
      if (routines[i].id == id) {
        index = i;
        break;
      }
    }
    
    if (index == -1 && routine_count < MAX_ROUTINES) {
      index = routine_count++;
    }
    
    if (index >= 0) {
      routines[index].id = id;
      routines[index].enabled = data["enabled"];
      routines[index].start_hour = data["start_hour"];
      routines[index].start_minute = data["start_minute"];
      routines[index].end_hour = data["end_hour"];
      routines[index].end_minute = data["end_minute"];
      routines[index].brightness = data["brightness"];
      routines[index].mode = data["mode"];
      
      Serial.printf("📅 ROUTINE SYNC: ID=%d, Name=%s\n", id, data["name"].as<const char*>());
      Serial.printf("  - Enabled: %s\n", routines[index].enabled ? "YES" : "NO");
      Serial.printf("  - Time: %02d:%02d to %02d:%02d\n", 
                    routines[index].start_hour, routines[index].start_minute,
                    routines[index].end_hour, routines[index].end_minute);
      Serial.printf("  - Brightness: %d (1-15 scale)\n", routines[index].brightness);
      Serial.printf("  - Mode: %d (0=warm, 1=white, 2=both)\n", routines[index].mode);
      Serial.printf("  - Total routines: %d/%d\n", routine_count, MAX_ROUTINES);
      
      sendSyncResponse("routine_sync_response", true, "Routine synced successfully");
    } else {
      Serial.println("📅 ERROR: Failed to sync routine: storage full");
      sendSyncResponse("routine_sync_response", false, "Storage full");
    }
  }
  else if (strcmp(action, "delete") == 0) {
    int id = doc["id"];
    
    // Find and remove routine
    for (int i = 0; i < routine_count; i++) {
      if (routines[i].id == id) {
        // Shift remaining routines
        for (int j = i; j < routine_count - 1; j++) {
          routines[j] = routines[j + 1];
        }
        routine_count--;
        Serial.printf("Routine %d deleted\n", id);
        sendSyncResponse("routine_sync_response", true, "Routine deleted");
        return;
      }
    }
    Serial.printf("Routine %d not found for deletion\n", id);
    sendSyncResponse("routine_sync_response", false, "Routine not found");
  }
}

void handleAlarmSync(JsonDocument& doc) {
  const char* action = doc["action"];
  
  if (strcmp(action, "upsert") == 0) {
    JsonObject data = doc["data"];
    int id = data["id"];
    
    // Find existing alarm or add new one
    int index = -1;
    for (int i = 0; i < alarm_count; i++) {
      if (alarms[i].id == id) {
        index = i;
        break;
      }
    }
    
    if (index == -1 && alarm_count < MAX_ALARMS) {
      index = alarm_count++;
    }
    
    if (index >= 0) {
      alarms[index].id = id;
      alarms[index].enabled = data["enabled"];
      alarms[index].wake_hour = data["wake_hour"];
      alarms[index].wake_minute = data["wake_minute"];
      alarms[index].start_hour = data["start_hour"];
      alarms[index].start_minute = data["start_minute"];
      alarms[index].duration_minutes = data["duration_minutes"];
      
      Serial.printf("Alarm %d synced\n", id);
      sendSyncResponse("alarm_sync_response", true, "Alarm synced successfully");
    } else {
      Serial.println("Failed to sync alarm: storage full");
      sendSyncResponse("alarm_sync_response", false, "Storage full");
    }
  }
  else if (strcmp(action, "delete") == 0) {
    int id = doc["id"];
    
    // Find and remove alarm
    for (int i = 0; i < alarm_count; i++) {
      if (alarms[i].id == id) {
        // Shift remaining alarms
        for (int j = i; j < alarm_count - 1; j++) {
          alarms[j] = alarms[j + 1];
        }
        alarm_count--;
        Serial.printf("Alarm %d deleted\n", id);
        sendSyncResponse("alarm_sync_response", true, "Alarm deleted");
        return;
      }
    }
    Serial.printf("Alarm %d not found for deletion\n", id);
    sendSyncResponse("alarm_sync_response", false, "Alarm not found");
  }
}

void handleFullSync(JsonDocument& doc) {
  // Clear existing data
  routine_count = 0;
  alarm_count = 0;
  
  // Sync routines
  if (doc["routines"].is<JsonArray>()) {
    JsonArray routineArray = doc["routines"];
    for (JsonObject routine : routineArray) {
      if (routine_count < MAX_ROUTINES) {
        routines[routine_count].id = routine["id"];
        routines[routine_count].enabled = routine["enabled"];
        routines[routine_count].start_hour = routine["start_hour"];
        routines[routine_count].start_minute = routine["start_minute"];
        routines[routine_count].end_hour = routine["end_hour"];
        routines[routine_count].end_minute = routine["end_minute"];
        routines[routine_count].brightness = routine["brightness"];
        routines[routine_count].mode = routine["mode"];
        routine_count++;
      }
    }
  }
  
  // Sync alarms
  if (doc["alarms"].is<JsonArray>()) {
    JsonArray alarmArray = doc["alarms"];
    for (JsonObject alarm : alarmArray) {
      if (alarm_count < MAX_ALARMS) {
        alarms[alarm_count].id = alarm["id"];
        alarms[alarm_count].enabled = alarm["enabled"];
        alarms[alarm_count].wake_hour = alarm["wake_hour"];
        alarms[alarm_count].wake_minute = alarm["wake_minute"];
        alarms[alarm_count].start_hour = alarm["start_hour"];
        alarms[alarm_count].start_minute = alarm["start_minute"];
        alarms[alarm_count].duration_minutes = alarm["duration_minutes"];
        alarm_count++;
      }
    }
  }
  
  Serial.printf("Full sync complete: %d routines, %d alarms\n", routine_count, alarm_count);
  sendSyncResponse("full_sync_response", true, "Full sync complete");
}

void sendSyncResponse(const char* type, bool success, const char* message) {
  JsonDocument doc;
  doc["type"] = type;
  doc["success"] = success;
  doc["message"] = message;
  
  String jsonString;
  serializeJson(doc, jsonString);
  ws.textAll(jsonString);
  
  Serial.printf("Sent sync response: %s\n", jsonString.c_str());
}

bool isManualControlLocked() {
  return (routineActive || alarmActive || sunSyncActive);
}

Routine* findRoutineById(int id) {
  if (id < 0) return nullptr;
  for (int i = 0; i < routine_count; i++) {
    if (routines[i].id == id) {
      return &routines[i];
    }
  }
  return nullptr;
}

Alarm* findAlarmById(int id) {
  if (id < 0) return nullptr;
  for (int i = 0; i < alarm_count; i++) {
    if (alarms[i].id == id) {
      return &alarms[i];
    }
  }
  return nullptr;
}

bool isWithinTimeRange(int startHour, int startMinute, int endHour, int endMinute, int currentTime) {
  int startTime = startHour * 60 + startMinute;
  int endTime = endHour * 60 + endMinute;

  if (endTime > startTime) {
    return currentTime >= startTime && currentTime <= endTime;
  }
  // wraps midnight
  return currentTime >= startTime || currentTime <= endTime;
}

void updateSuppressionWindows(int currentTime) {
  if (routineSuppressed) {
    if (!isWithinTimeRange(suppressedRoutine.start_hour, suppressedRoutine.start_minute,
                           suppressedRoutine.end_hour, suppressedRoutine.end_minute, currentTime)) {
      Serial.printf("Routine %d suppression window ended\n", suppressedRoutine.id);
      routineSuppressed = false;
    }
  }

  if (alarmSuppressed) {
    if (!isWithinTimeRange(suppressedAlarm.start_hour, suppressedAlarm.start_minute,
                           suppressedAlarm.wake_hour, suppressedAlarm.wake_minute, currentTime)) {
      Serial.printf("Alarm %d suppression window ended\n", suppressedAlarm.id);
      alarmSuppressed = false;
    }
  }
}

void blinkLamp(uint8_t count, uint16_t intervalMs) {
  int savedCh0 = ledcRead(0);
  int savedCh1 = ledcRead(1);
  bool lampWasOn = isOn;

  for (uint8_t i = 0; i < count; ++i) {
    // Off phase
    ledcWrite(0, 15);
    ledcWrite(1, 15);
    delay(intervalMs);

    // On phase - restore saved channels or provide a gentle pulse if lamp was off
    if (lampWasOn) {
      ledcWrite(0, savedCh0);
      ledcWrite(1, savedCh1);
    } else {
      ledcWrite(0, 12);
      ledcWrite(1, 12);
    }
    delay(intervalMs);
  }

  applyOutput();
}

void sendSunSyncState(bool active, const char* source) {
  JsonDocument doc;
  doc["type"] = "sun_sync_state";
  doc["active"] = active;
  doc["source"] = source;
  doc["timestamp_ms"] = millis();

  String jsonString;
  serializeJson(doc, jsonString);
  ws.textAll(jsonString);

  Serial.printf("Sent sun sync state (%s): %s\n", source, jsonString.c_str());
}

void broadcastOverrideEvent(const char* source, bool routineWasActive, bool alarmWasActive, bool sunSyncWasActive) {
  JsonDocument doc;
  doc["type"] = "schedule_override_event";
  doc["source"] = source;
  doc["timestamp_ms"] = millis();
  doc["routine_disabled"] = routineWasActive;
  doc["alarm_disabled"] = alarmWasActive;
  doc["sun_sync_disabled"] = sunSyncWasActive;
  doc["routine_suppressed"] = routineSuppressed;
  doc["alarm_suppressed"] = alarmSuppressed;
  doc["sun_sync_active"] = sunSyncActive;

  String jsonString;
  serializeJson(doc, jsonString);
  ws.textAll(jsonString);

  Serial.printf("Sent override event: %s\n", jsonString.c_str());
}

void handleSunSyncState(bool active, const char* source) {
  bool previous = sunSyncActive;
  sunSyncActive = active;

  if (active) {
    sunSyncDisabledByHardware = false;
  } else if (strcmp(source, "hardware") == 0) {
    sunSyncDisabledByHardware = true;
  } else {
    sunSyncDisabledByHardware = false;
  }

  Serial.printf("Sun sync state updated by %s -> %s\n", source, active ? "ACTIVE" : "INACTIVE");

  if (previous != sunSyncActive) {
    sendStateUpdate();
  }
}

void handleTripleClick() {
  bool routineWasActive = routineActive;
  bool alarmWasActive = alarmActive;
  bool sunSyncWasActive = sunSyncActive;

  Serial.println("Triple click detected: disabling active schedules for current instance");

  if (routineActive) {
    Routine* routinePtr = findRoutineById(activeRoutineId);
    if (routinePtr != nullptr) {
      suppressedRoutine = *routinePtr;
      routineSuppressed = true;
      Serial.printf("Routine %d suppressed for current window\n", suppressedRoutine.id);
    } else {
      routineSuppressed = false;
      Serial.println("Warning: active routine ID not found for suppression");
    }
    routineActive = false;
    activeRoutineId = -1;
    lastRoutineMinute = -1;
    wasOffBeforeRoutine = false;
  }

  if (alarmActive) {
    Alarm* alarmPtr = findAlarmById(activeAlarmId);
    if (alarmPtr != nullptr) {
      suppressedAlarm = *alarmPtr;
      alarmSuppressed = true;
      Serial.printf("Alarm %d suppressed for current window\n", suppressedAlarm.id);
    } else {
      alarmSuppressed = false;
      Serial.println("Warning: active alarm ID not found for suppression");
    }
    alarmActive = false;
    activeAlarmId = -1;
    lastAlarmMinute = -1;
    wasOffBeforeAlarm = false;
  }

  if (sunSyncActive) {
    sunSyncActive = false;
    sunSyncDisabledByHardware = true;
    sendSunSyncState(false, "hardware");
  }

  if (routineWasActive || alarmWasActive || sunSyncWasActive) {
    blinkLamp(OVERRIDE_BLINK_COUNT, OVERRIDE_BLINK_INTERVAL_MS);
  } else {
    Serial.println("Triple click detected but no active routine/alarm/sun sync to disable");
  }

  applyOutput();
  sendStateUpdate();
  broadcastOverrideEvent("hardware", routineWasActive, alarmWasActive, sunSyncWasActive);
}

void handleTimeSync(JsonDocument& doc) {
  if (doc["timestamp"].is<long long>()) {
    long long timestamp = doc["timestamp"];
    
    // Convert milliseconds to seconds (UTC timestamp)
    time_t utcTimeSeconds = timestamp / 1000;
    
    // Print UTC time first
    struct tm* utcTime = gmtime(&utcTimeSeconds);
    Serial.printf("🕐 RECEIVED UTC: %04d-%02d-%02d %02d:%02d:%02d\n",
                  utcTime->tm_year + 1900, utcTime->tm_mon + 1, utcTime->tm_mday,
                  utcTime->tm_hour, utcTime->tm_min, utcTime->tm_sec);
    
    // Set system time with UTC time (timezone conversion handled automatically by configTzTime)
    struct timeval tv;
    tv.tv_sec = utcTimeSeconds;
    tv.tv_usec = 0;
    settimeofday(&tv, NULL);
    
    // Print what the ESP32 thinks the time is after setting
    struct tm timeinfo;
    if (getLocalTime(&timeinfo)) {
      Serial.printf("🕐 ESP32 AUCKLAND TIME: %04d-%02d-%02d %02d:%02d:%02d\n",
                    timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
                    timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    } else {
      Serial.println("🕐 ERROR: Failed to get Auckland local time after sync");
    }

    sendSyncResponse("time_sync_response", true, "Time synchronized to Auckland timezone with automatic DST");
  } else {
    Serial.println("🕐 ERROR: Invalid time sync data - missing timestamp");
    sendSyncResponse("time_sync_response", false, "Invalid time data");
  }
}

void checkSchedule() {
  // Only check schedule if we have a valid time
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    static unsigned long lastTimeWarning = 0;
    if (millis() - lastTimeWarning > 30000) { // Warn every 30 seconds
      Serial.println("⚠️  SCHEDULE: No valid time available for schedule checking");
      lastTimeWarning = millis();
    }
    return; // No valid time available
  }
  
  int currentHour = timeinfo.tm_hour;
  int currentMinute = timeinfo.tm_min;
  int currentTime = currentHour * 60 + currentMinute; // Convert to minutes since midnight

  updateSuppressionWindows(currentTime);

  // Debug: Print current time only when minute changes
  static int lastDebugMinute = -1;
  if (currentMinute != lastDebugMinute) {
    Serial.printf("🕐 SCHEDULE CHECK: Current time %02d:%02d (%d minutes), Routines: %d, Alarms: %d\n",
                  currentHour, currentMinute, currentTime, routine_count, alarm_count);
    lastDebugMinute = currentMinute;
  }

  bool foundActiveRoutine = false;

  // Check routines
  for (int i = 0; i < routine_count; i++) {
    if (!routines[i].enabled) continue;

    int startTime = routines[i].start_hour * 60 + routines[i].start_minute;
    int endTime = routines[i].end_hour * 60 + routines[i].end_minute;

    // Handle routines that span midnight
    bool inTimeRange;
    if (endTime > startTime) {
      inTimeRange = (currentTime >= startTime && currentTime <= endTime);
    } else {
      inTimeRange = (currentTime >= startTime || currentTime <= endTime);
    }

    if (inTimeRange) {
      if (routineSuppressed && suppressedRoutine.id == routines[i].id) {
        Serial.printf("📅 Routine %d is suppressed for current window; skipping application\n", routines[i].id);
        return;
      }

      foundActiveRoutine = true;

      // Only trigger routine activation once per minute to avoid repeated triggers
      bool shouldActivate = false;
      if (!routineActive || activeRoutineId != routines[i].id) {
        shouldActivate = true;
      } else if (lastRoutineMinute != currentMinute) {
        // Minute has changed, allow update (for gradual changes, etc.)
        shouldActivate = true;
      }

      if (shouldActivate) {
        // Save current state if starting a new routine
        if (!routineActive) {
          originalIsOn = isOn;
          originalBrightness = brightness;
          originalMode = mode;
          wasOffBeforeRoutine = !isOn;
          Serial.printf("✨ Starting routine %d: saved state (isOn=%s, brightness=%d, mode=%d)\n",
                        routines[i].id, originalIsOn ? "true" : "false", originalBrightness, (int)originalMode);
        }

        routineActive = true;
        activeRoutineId = routines[i].id;
        lastRoutineMinute = currentMinute;

        // Apply routine settings
        brightness = routines[i].brightness;
        mode = (Mode)routines[i].mode;
        isOn = true;  // Routine always turns lamp on
        applyOutput();

        Serial.printf("📅 Applied routine %d: brightness=%d, mode=%d at %02d:%02d\n",
                      routines[i].id, brightness, (int)mode, currentHour, currentMinute);
        sendStateUpdate();
      }
      return; // Only apply one routine at a time
    }
  }
  
  // If no routine is active now but one was active before
  if (routineActive && !foundActiveRoutine) {
    Serial.printf("⏹️  Routine %d ended: keeping current state (isOn=%s, brightness=%d, mode=%d)\n",
                  activeRoutineId, isOn ? "true" : "false", brightness, (int)mode);

    routineActive = false;
    activeRoutineId = -1;
    wasOffBeforeRoutine = false;
    lastRoutineMinute = -1;

    // State remains as the routine left it; notify clients so they stay in sync
    sendStateUpdate();
    return;
  }

  // Check alarms (sunrise simulation) - only if no routine is active
  if (!routineActive) {
    bool foundActiveAlarm = false;

    for (int i = 0; i < alarm_count; i++) {
      if (!alarms[i].enabled) continue;

      int startTime = alarms[i].start_hour * 60 + alarms[i].start_minute;
      int wakeTime = alarms[i].wake_hour * 60 + alarms[i].wake_minute;

      if (currentTime >= startTime && currentTime <= wakeTime) {
        if (alarmSuppressed && suppressedAlarm.id == alarms[i].id) {
          Serial.printf("⏰ Alarm %d is suppressed for current window; skipping application\n", alarms[i].id);
          return;
        }

        foundActiveAlarm = true;

        // Only trigger alarm updates once per minute
        bool shouldUpdate = false;
        if (!alarmActive || activeAlarmId != alarms[i].id) {
          shouldUpdate = true;
        } else if (lastAlarmMinute != currentMinute) {
          shouldUpdate = true; // Update every minute for gradual brightness increase
        }

        if (shouldUpdate) {
          // Save current state if starting a new alarm
          if (!alarmActive) {
            alarmOriginalIsOn = isOn;
            alarmOriginalBrightness = brightness;
            alarmOriginalMode = mode;
            wasOffBeforeAlarm = !isOn;
            Serial.printf("🌅 Starting alarm %d: saved state (isOn=%s, brightness=%d, mode=%d)\n",
                          alarms[i].id, alarmOriginalIsOn ? "true" : "false", alarmOriginalBrightness, (int)alarmOriginalMode);
          }

          alarmActive = true;
          activeAlarmId = alarms[i].id;
          lastAlarmMinute = currentMinute;

          // Calculate progress through alarm (0.0 to 1.0)
          float progress = (float)(currentTime - startTime) / (float)alarms[i].duration_minutes;
          progress = constrain(progress, 0.0, 1.0);

          // Gradually increase brightness across both LED channels
          brightness = (int)(progress * 15); // Scale to 0-15
          mode = MODE_BOTH; // Use mixed output so both LEDs ramp together
          isOn = true;
          applyOutput();

          Serial.printf("🌅 Alarm %d progress: %.2f, brightness=%d at %02d:%02d\n",
                        alarms[i].id, progress, brightness, currentHour, currentMinute);
          sendStateUpdate();
        }
        return; // Only apply one alarm at a time
      }
    }

    // If no alarm is active now but one was active before
    if (alarmActive && !foundActiveAlarm) {
      Serial.printf("⏹️  Alarm %d ended: holding daytime state (isOn=true, brightness=15, mode=%d)\n",
                    activeAlarmId, (int)MODE_BOTH);

      // Lock in full brightness mixed mode until user or another event changes it
      isOn = true;
      brightness = 15;
      mode = MODE_BOTH;

      alarmActive = false;
      activeAlarmId = -1;
      wasOffBeforeAlarm = false;
      lastAlarmMinute = -1;

      applyOutput();
      sendStateUpdate();
      return;
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);

  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 4); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 4); ledcAttachPin(LED_B_PIN, 1);


  WiFi.begin(SSID, PASSWORD);
  Serial.print("WiFi…");
  unsigned long wifiStart = millis();
  const unsigned long wifiTimeout = 5000; // 5 seconds timeout
  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < wifiTimeout) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(WiFi.localIP());
    
    // Initialize time for Auckland, New Zealand with automatic DST handling
    configTzTime(timezone, ntpServer);
    Serial.println("NTP time initialized for Auckland with automatic NZST/NZDT transitions");
    
    // Wait a bit and show current Auckland time
    delay(2000);
    struct tm timeinfo;
    if (getLocalTime(&timeinfo)) {
      Serial.printf("🕐 Current Auckland time: %04d-%02d-%02d %02d:%02d:%02d\n",
                    timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
                    timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
    }
  } else {
    Serial.println("\nWiFi not connected, continuing without WiFi.");
  }

  // ----- mDNS -----
  if (!MDNS.begin("circadian-light")) {          // hostname = circadian-light.local
    Serial.println("Error starting mDNS");
  } else {
    Serial.println("mDNS responder started");
    MDNS.addService("_ws", "_tcp", 80);          // advertise the WebSocket port
  }
  // -----------------

  ws.onEvent(onWSMsg);
  server.addHandler(&ws);
  server.begin();

  pinMode(ROTARY_BTN, INPUT_PULLUP);
  {
    int idle = digitalRead(ROTARY_BTN);
    Serial.printf("ROTARY_BTN idle read: %d (expect %s when unpressed)\n",
                  idle, BUTTON_ACTIVE_LOW ? "HIGH" : "LOW");
  }

  applyOutput();
}

void loop() {
  // --- Rotary encoder: adjust master brightness (minimum 1 when on, 0-15 when off) ---
  encoder.tick();
  static int lastPos = encoder.getPosition();
  int pos = encoder.getPosition();
  if (pos != lastPos) {
    int delta = pos - lastPos;
    lastPos = pos;

    if (isManualControlLocked()) {
      Serial.println("Rotary input ignored: schedule or sun sync currently active");
    } else {
      // Determine brightness limits based on lamp on/off state
      int minBrightness = isOn ? 1 : 0;  // Minimum 1 when on, can be 0 when off
      int maxBrightness = 15;

      int newBrightness = constrain(brightness + delta * 1, minBrightness, maxBrightness);
      if (newBrightness != brightness) {
        brightness = newBrightness;
        Serial.printf("Brightness -> %d (limits: %d-%d, isOn: %s)\n", 
                      brightness, minBrightness, maxBrightness, isOn ? "true" : "false");
        applyOutput();
        sendStateUpdate(); // Send update to Flutter app
      }
    }
  }

  // --- Button: handle single/double/triple clicks ---
  static bool prevPressed = false;            // logical pressed state (polarity-agnostic)
  static unsigned long lastChange = 0;
  unsigned long now = millis();

  int raw = digitalRead(ROTARY_BTN);
  bool pressed = BUTTON_ACTIVE_LOW ? (raw == LOW) : (raw == HIGH);

  if (pressed != prevPressed && (now - lastChange) > DEBOUNCE_MS) {
    lastChange = now;

    // Trigger on RELEASE edge regardless of polarity
    if (prevPressed && !pressed) {
      if (clickCount == 0) {
        firstClickTime = now;
      }
      clickCount++;
      lastClickReleaseTime = now;
      Serial.println("Button RELEASE detected");

      if (clickCount >= 3 && (now - firstClickTime) <= MULTI_CLICK_WINDOW_MS) {
        handleTripleClick();
        clickCount = 0;
      }
    }

    prevPressed = pressed;
  }

  if (clickCount > 0 && (now - lastClickReleaseTime) > MULTI_CLICK_WINDOW_MS) {
    uint8_t clicks = clickCount;
    clickCount = 0;

    if (clicks >= 3) {
      handleTripleClick();
    } else if (clicks == 2) {
      if (isManualControlLocked()) {
        Serial.println("Double click ignored: schedule or sun sync active");
      } else {
        mode = (Mode)((mode + 1) % 3); // warm -> white -> both -> warm ...
        Serial.printf("Double click: mode -> %d (0=WARM,1=WHITE,2=BOTH)\n", (int)mode);
        applyOutput();
        sendStateUpdate();
      }
    } else if (clicks == 1) {
      if (isManualControlLocked()) {
        Serial.println("Single click ignored: schedule or sun sync active");
      } else {
        isOn = !isOn;
        Serial.printf("Single click: isOn -> %s\n", isOn ? "ON" : "OFF");
        applyOutput();
        sendStateUpdate();
      }
    }
  }

  // Check schedule for routines and alarms
  if (millis() - lastScheduleCheck >= SCHEDULE_CHECK_INTERVAL) {
    lastScheduleCheck = millis();
    checkSchedule();
  }

  ws.cleanupClients();
}