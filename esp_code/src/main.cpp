#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>
#include <time.h>

// const char* SSID     = "MAGS LAB";
// const char* PASSWORD = "vXJC@(Lw";

// const char* SSID     = "HUAWEI-2.4G-g3AY";
// const char* PASSWORD = "FW9ta64r";


#define LED_BUILTIN 2   // builtin LED (GPIO2)
#define LED_A_PIN   16  // first LED group PWM (warm)
#define LED_B_PIN   17  // second LED group PWM (white)

#define ROTARY_DT  32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

const char* ESP_IP = "10.210.232.242";   // update if the ESP32 reboots with a new IP
const char* WS_URL = "ws://10.210.232.242/ws";

// Time zone configuration (adjust for your location)
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 0;  // GMT offset in seconds
const int daylightOffset_sec = 3600;  // Daylight offset in seconds

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
const unsigned long SCHEDULE_CHECK_INTERVAL = 60000; // Check every minute

// ===== New simplified control state =====
enum Mode { MODE_WARM = 0, MODE_WHITE = 1, MODE_BOTH = 2 };

// ===== Routine state tracking =====
bool routineActive = false;          // Is a routine currently running?
bool wasOffBeforeRoutine = false;    // Was the lamp off before routine started?
int activeRoutineId = -1;            // ID of currently active routine
int originalBrightness = 8;          // Brightness before routine
Mode originalMode = MODE_BOTH;       // Mode before routine
bool originalIsOn = true;            // On/off state before routine

Mode mode = MODE_BOTH;                 // double-click cycles this
int brightness = 0;                  // 0-15 master brightness (independent of on/off & mode)
bool isOn = true;                      // single-click toggles this

// Button click state (robust, polarity-agnostic)
uint8_t clickCount = 0;                // 1 = single (after timeout), 2 = double
unsigned long firstClickTime = 0;      // time of first click
const uint16_t DOUBLE_CLICK_MS = 500;  // double-click window (ms)
const uint16_t DEBOUNCE_MS     = 35;   // debounce time (ms)
const bool BUTTON_ACTIVE_LOW   = true; // set false if wired active-high

// ===== Forward Declarations =====
void handleRoutineSync(JsonDocument& doc);
void handleAlarmSync(JsonDocument& doc);
void handleFullSync(JsonDocument& doc);
void sendSyncResponse(const char* type, bool success, const char* message);

// ===== Helpers =====
void sendStateUpdate() {
  // Send current state to all connected WebSocket clients
  JsonDocument doc;
  JsonObject state = doc["state"].to<JsonObject>();
  state["brightness"] = brightness;
  state["mode"] = (int)mode;
  state["on"] = isOn;
  
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
      
      Serial.printf("Routine %d synced\n", id);
      sendSyncResponse("routine_sync_response", true, "Routine synced successfully");
    } else {
      Serial.println("Failed to sync routine: storage full");
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

void checkSchedule() {
  // Only check schedule if we have a valid time
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return; // No valid time available
  }
  
  int currentHour = timeinfo.tm_hour;
  int currentMinute = timeinfo.tm_min;
  int currentTime = currentHour * 60 + currentMinute; // Convert to minutes since midnight
  
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
      foundActiveRoutine = true;
      
      // If this is a new routine starting
      if (!routineActive || activeRoutineId != routines[i].id) {
        // Save current state if starting a new routine
        if (!routineActive) {
          originalIsOn = isOn;
          originalBrightness = brightness;
          originalMode = mode;
          wasOffBeforeRoutine = !isOn;
          Serial.printf("Starting routine %d: saved state (isOn=%s, brightness=%d, mode=%d)\n",
                        routines[i].id, originalIsOn ? "true" : "false", originalBrightness, (int)originalMode);
        }
        
        routineActive = true;
        activeRoutineId = routines[i].id;
      }
      
      // Apply routine settings
      brightness = routines[i].brightness;
      mode = (Mode)routines[i].mode;
      isOn = true;  // Routine always turns lamp on
      applyOutput();
      
      Serial.printf("Applied routine %d: brightness=%d, mode=%d\n", 
                    routines[i].id, brightness, (int)mode);
      sendStateUpdate();
      return; // Only apply one routine at a time
    }
  }
  
  // If no routine is active now but one was active before
  if (routineActive && !foundActiveRoutine) {
    Serial.printf("Routine %d ended: restoring state (isOn=%s, brightness=%d, mode=%d)\n",
                  activeRoutineId, originalIsOn ? "true" : "false", originalBrightness, (int)originalMode);
    
    // Restore original state
    isOn = originalIsOn;
    brightness = originalBrightness;
    mode = originalMode;
    
    routineActive = false;
    activeRoutineId = -1;
    wasOffBeforeRoutine = false;
    
    applyOutput();
    sendStateUpdate();
    return;
  }
  
  // Check alarms (sunrise simulation) - only if no routine is active
  if (!routineActive) {
    for (int i = 0; i < alarm_count; i++) {
      if (!alarms[i].enabled) continue;
      
      int startTime = alarms[i].start_hour * 60 + alarms[i].start_minute;
      int wakeTime = alarms[i].wake_hour * 60 + alarms[i].wake_minute;
      
      if (currentTime >= startTime && currentTime <= wakeTime) {
        // Calculate progress through alarm (0.0 to 1.0)
        float progress = (float)(currentTime - startTime) / (float)alarms[i].duration_minutes;
        progress = constrain(progress, 0.0, 1.0);
        
        // Gradually increase brightness
        brightness = (int)(progress * 15); // Scale to 0-15
        mode = MODE_WARM; // Start with warm light for sunrise
        isOn = true;
        applyOutput();
        
        Serial.printf("Alarm %d progress: %.2f, brightness=%d\n", 
                      alarms[i].id, progress, brightness);
        sendStateUpdate();
        return; // Only apply one alarm at a time
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(ROTARY_BTN, INPUT_PULLUP);

  // Check if button is held at startup to reset WiFi
  delay(100); // Give button time to settle
  if (digitalRead(ROTARY_BTN) == LOW) { // Button pressed at startup
    Serial.println("Button held at startup - clearing WiFi credentials...");
    WiFi.disconnect(true, true); // Clear saved WiFi credentials
    delay(1000);
    Serial.println("WiFi credentials cleared. Release button to continue.");
    while (digitalRead(ROTARY_BTN) == LOW) {
      delay(100); // Wait for button release
      digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN)); // Blink LED
    }
  }

  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 4); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 4); ledcAttachPin(LED_B_PIN, 1);

  // Try to connect with saved WiFi credentials first
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.setAutoConnect(true);
  WiFi.begin(); // Attempt to connect with previously saved credentials

  Serial.print("Checking for saved WiFi credentials...");
  unsigned long wifiStart = millis();
  const unsigned long wifiTimeout = 10000; // 10 seconds timeout

  while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < wifiTimeout) {
    delay(500);
    Serial.print(".");
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN)); // Blink LED while connecting
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\nConnected to WiFi! IP: ");
    Serial.println(WiFi.localIP());
    digitalWrite(LED_BUILTIN, HIGH); // LED on when connected

    // Initialize time
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    Serial.println("NTP time initialized");
  } else {
    Serial.println("\nNo saved WiFi found. Starting SmartConfig...");

    // Start SmartConfig with type ESPTOUCH_V2 for better compatibility
    WiFi.beginSmartConfig(SC_TYPE_ESPTOUCH_V2);

    Serial.println("Waiting for SmartConfig from mobile app...");
    Serial.println("Use the Flutter app to send WiFi credentials");
    Serial.println("\nSmartConfig Status: WAITING FOR CREDENTIALS");

    // Wait for SmartConfig to complete with timeout
    unsigned long smartConfigStart = millis();
    const unsigned long smartConfigTimeout = 120000; // 120 seconds timeout for better reliability
    bool smartConfigReceived = false;

    while (!smartConfigReceived && millis() - smartConfigStart < smartConfigTimeout) {
      delay(500);  // Increased delay for stability

      // Check SmartConfig status
      if (WiFi.smartConfigDone()) {
        smartConfigReceived = true;
        Serial.println("\n✓ SmartConfig credentials received!");
        break;
      }

      // Fast blink LED during SmartConfig
      digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));

      // Print status every 5 seconds
      if ((millis() - smartConfigStart) % 5000 < 500) {
        Serial.printf("\n[%lu s] Still waiting for credentials...\n", (millis() - smartConfigStart) / 1000);
      }

      // Check if connected periodically
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n✓ Connected during SmartConfig!");
        smartConfigReceived = true;
        break;
      }
    }

    if (smartConfigReceived) {
      // Stop SmartConfig first
      WiFi.stopSmartConfig();

      Serial.println("\nSmartConfig data received, attempting connection...");

      // Get the credentials from SmartConfig (they should be auto-applied)
      String ssid = WiFi.SSID();
      String psk = WiFi.psk();

      Serial.print("Received SSID: ");
      Serial.println(ssid.length() > 0 ? ssid : "(empty)");
      Serial.print("Received PSK: ");
      Serial.println(psk.length() > 0 ? "***hidden***" : "(empty)");

      // Force reconnection with received credentials
      if (ssid.length() > 0) {
        WiFi.disconnect();
        delay(100);
        WiFi.begin(ssid.c_str(), psk.c_str());
      }

      // Wait for WiFi connection after SmartConfig
      Serial.println("\nAttempting to connect to WiFi...");
      wifiStart = millis();
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && millis() - wifiStart < 30000) { // 30 second timeout
        delay(500);
        Serial.print(".");
        attempts++;
        if (attempts % 20 == 0) {
          Serial.printf("\nStatus: %d (0=IDLE, 1=NO_SSID, 3=CONNECTED, 4=CONNECT_FAILED, 5=CONNECTION_LOST, 6=DISCONNECTED)\n", WiFi.status());
        }
      }
    } else {
      Serial.println("\n✗ SmartConfig timeout - no credentials received");
      WiFi.stopSmartConfig();
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.print("\nConnected to WiFi! IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("SSID: ");
      Serial.println(WiFi.SSID());
      digitalWrite(LED_BUILTIN, HIGH); // LED on when connected

      // Initialize time
      configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
      Serial.println("NTP time initialized");
    } else {
      Serial.println("\nFailed to connect with SmartConfig credentials.");
      Serial.println("Please reset the device and try again.");
      digitalWrite(LED_BUILTIN, LOW); // LED off if failed

      // Optionally restart ESP32 to try again
      delay(5000);
      ESP.restart();
    }
  }

  // ----- mDNS -----
  if (!MDNS.begin("circadian-light")) {          // hostname = circadian-light.local
    Serial.println("Error starting mDNS");
  } else {
    Serial.println("mDNS responder started");
    MDNS.addService("_ws", "_tcp", 80);          // advertise the WebSocket port
    MDNS.addService("_circadian", "_tcp", 80);   // advertise circadian service for app discovery
    Serial.println("mDNS services: _ws._tcp.80, _circadian._tcp.80");
  }
  // -----------------

  ws.onEvent(onWSMsg);
  server.addHandler(&ws);
  server.begin();

  // ROTARY_BTN already configured at start of setup()
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

  // --- Button: single click = toggle on/off; double click = cycle modes ---
  static bool prevPressed = false;            // logical pressed state (polarity-agnostic)
  static unsigned long lastChange = 0;
  unsigned long now = millis();

  int raw = digitalRead(ROTARY_BTN);
  bool pressed = BUTTON_ACTIVE_LOW ? (raw == LOW) : (raw == HIGH);

  if (pressed != prevPressed && (now - lastChange) > DEBOUNCE_MS) {
    lastChange = now;

    // Trigger on RELEASE edge regardless of polarity
    if (prevPressed && !pressed) {
      if (clickCount == 0) firstClickTime = now;
      clickCount++;
      Serial.println("Button RELEASE detected");

      // If second release arrives within window -> double click
      if (clickCount == 2 && (now - firstClickTime) <= DOUBLE_CLICK_MS) {
        mode = (Mode)((mode + 1) % 3); // warm -> white -> both -> warm ...
        Serial.printf("Double click: mode -> %d (0=WARM,1=WHITE,2=BOTH)\n", (int)mode);
        applyOutput();
        sendStateUpdate(); // Send update to Flutter app
        clickCount = 0;
      }
    }

    prevPressed = pressed;
  }

  // If one release occurred and window expired -> single click
  if (clickCount == 1 && (millis() - firstClickTime) > DOUBLE_CLICK_MS) {
    isOn = !isOn;
    Serial.printf("Single click: isOn -> %s\n", isOn ? "ON" : "OFF");
    applyOutput();
    sendStateUpdate(); // Send update to Flutter app
    clickCount = 0;
  }

  // Check schedule for routines and alarms
  if (millis() - lastScheduleCheck >= SCHEDULE_CHECK_INTERVAL) {
    lastScheduleCheck = millis();
    checkSchedule();
  }

  ws.cleanupClients();
}