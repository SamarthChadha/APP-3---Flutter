#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>
#include <Preferences.h>

// Remove hardcoded credentials - will be provided via SmartConfig
// const char* SSID     = "MAGS LAB";
// const char* PASSWORD = "vXJC@(Lw";

#define LED_BUILTIN 2   // builtin LED (GPIO2)
#define LED_A_PIN   16  // first LED group PWM (warm)
#define LED_B_PIN   17  // second LED group PWM (white)

#define ROTARY_DT  32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

// WiFi credentials will be stored/retrieved from NVS
Preferences preferences;

// WiFi and SmartConfig management
String savedSSID = "";
String savedPassword = "";
bool wifiConnected = false;
bool smartConfigActive = false;
unsigned long smartConfigStartTime = 0;
const unsigned long SMARTCONFIG_TIMEOUT = 120000; // 2 minutes timeout

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");

// Function declarations
void startSmartConfig();
void stopSmartConfig();
void handleSmartConfig();
bool loadWiFiCredentials();
void saveWiFiCredentials(String ssid, String password);
void connectToWiFi();
void handleWiFiEvents();
void startWebServer();

RotaryEncoder encoder(ROTARY_DT, ROTARY_CLK);

// ===== New simplified control state =====
enum Mode { MODE_WARM = 0, MODE_WHITE = 1, MODE_BOTH = 2 };
Mode mode = MODE_BOTH;                 // double-click cycles this
int brightness = 0;                  // 0-15 master brightness (independent of on/off & mode)
bool isOn = true;                      // single-click toggles this

// Button click state (robust, polarity-agnostic)
uint8_t clickCount = 0;                // 1 = single (after timeout), 2 = double
unsigned long firstClickTime = 0;      // time of first click
const uint16_t DOUBLE_CLICK_MS = 500;  // double-click window (ms)
const uint16_t DEBOUNCE_MS     = 35;   // debounce time (ms)
const bool BUTTON_ACTIVE_LOW   = true; // set false if wired active-high

// ===== Helpers =====
void applyOutput() {
  int ch0 = 15;
  int ch1 = 15;

  if (!isOn) {
    // When OFF: force both channels to 15 (inverted logic)
    ledcWrite(0, ch0);
    ledcWrite(1, ch1);
    Serial.printf("applyOutput: isOn=%d mode=%d brightness=%d -> ch0=%d ch1=%d (OFF)\n",
                  (int)isOn, (int)mode, brightness, ch0, ch1);
    return;
  }

  // When ON: compute channel values based on mode
  switch (mode) {
    case MODE_WARM:   // mode 0
      ch0 = brightness; // warm channel active
      ch1 = 15;         // white channel off (in inverted logic)
      break;
    case MODE_WHITE:  // mode 1
      ch0 = 15;
      ch1 = brightness;
      break;
    case MODE_BOTH:   // mode 2
    default:
      ch0 = brightness;
      ch1 = brightness;
      break;
  }

  ledcWrite(0, ch0);
  ledcWrite(1, ch1);
  Serial.printf("applyOutput: isOn=%d mode=%d brightness=%d -> ch0=%d ch1=%d\n",
                (int)isOn, (int)mode, brightness, ch0, ch1);
}

void onWSMsg(AsyncWebSocket *ws, AsyncWebSocketClient *client,
             AwsEventType type, void *arg, uint8_t *data, size_t len) {
  // --- Debug: log connect / disconnect ---
  if (type == WS_EVT_CONNECT) {
    Serial.printf("WebSocket client #%u connected\n", client->id());
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
  if (doc["brightness"].is<int>()) {    // brightness control from app
    brightness = constrain(doc["brightness"].as<int>(), 0, 15);
    Serial.printf("WebSocket: brightness -> %d\n", brightness);
    applyOutput();
    recognized = true;
  }
  if (doc["mode"].is<int>()) {    // mode control from app
    int newMode = constrain(doc["mode"].as<int>(), 0, 2);
    mode = (Mode)newMode;
    Serial.printf("WebSocket: mode -> %d (0=WARM,1=WHITE,2=BOTH)\n", newMode);
    applyOutput();
    recognized = true;
  }
  if (doc["on"].is<bool>()) {    // on/off control from app
    isOn = doc["on"].as<bool>();
    Serial.printf("WebSocket: isOn -> %s\n", isOn ? "ON" : "OFF");
    applyOutput();
    recognized = true;
  }

  if (!recognized) {
    Serial.println("WS RX: no recognized keys in payload");
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);

  // Initialize preferences for NVS storage
  preferences.begin("wifi", false);

  // Initialize PWM channels
  ledcSetup(0, 5000, 4); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 4); ledcAttachPin(LED_B_PIN, 1);

  // Set WiFi mode to station
  WiFi.mode(WIFI_STA);

  // Set up WiFi event handlers
  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
    switch(event) {
      case ARDUINO_EVENT_WIFI_STA_GOT_IP:
        Serial.println("WiFi connected!");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
        wifiConnected = true;
        if (smartConfigActive) {
          stopSmartConfig();
        }
        startWebServer();
        break;
        
      case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
        Serial.println("WiFi disconnected!");
        wifiConnected = false;
        break;
        
      case ARDUINO_EVENT_WIFI_STA_START:
        Serial.println("WiFi station started");
        break;

      case ARDUINO_EVENT_SC_SCAN_DONE:
        Serial.println("SmartConfig: Scan done");
        break;

      case ARDUINO_EVENT_SC_FOUND_CHANNEL:
        Serial.println("SmartConfig: Found channel");
        break;

      case ARDUINO_EVENT_SC_GOT_SSID_PSWD:
        Serial.println("SmartConfig: Received SSID and Password via event!");
        // This should trigger automatic connection
        break;

      case ARDUINO_EVENT_SC_SEND_ACK_DONE:
        Serial.println("SmartConfig: ACK sent to phone");
        break;
        
      default:
        if (event >= ARDUINO_EVENT_SC_SCAN_DONE && event <= ARDUINO_EVENT_SC_SEND_ACK_DONE) {
          Serial.printf("SmartConfig Event: %d\n", event);
        }
        break;
    }
  });

  // Try to load saved credentials and connect
  if (loadWiFiCredentials()) {
    Serial.println("Found saved WiFi credentials, attempting to connect...");
    connectToWiFi();
  } else {
    Serial.println("No saved credentials found, starting SmartConfig...");
    startSmartConfig();
  }

  // Initialize rotary button
  pinMode(ROTARY_BTN, INPUT_PULLUP);
  {
    int idle = digitalRead(ROTARY_BTN);
    Serial.printf("ROTARY_BTN idle read: %d (expect %s when unpressed)\n",
                  idle, BUTTON_ACTIVE_LOW ? "HIGH" : "LOW");
  }

  // Apply initial LED output
  applyOutput();
}

void loop() {
  // Handle SmartConfig if active
  handleSmartConfig();

  // Only process other inputs if WiFi is connected and web server is running
  if (wifiConnected) {
    // --- Rotary encoder: adjust master brightness (independent of on/off & mode) ---
    encoder.tick();
    static int lastPos = encoder.getPosition();
    int pos = encoder.getPosition();
    if (pos != lastPos) {
      int delta = pos - lastPos;
      lastPos = pos;
      brightness = constrain(brightness + delta * 1, 0, 15); // step = 5
      Serial.printf("Brightness -> %d\n", brightness);
      applyOutput();
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
      clickCount = 0;
    }

    ws.cleanupClients();
  } else {
    // If not connected, just blink the builtin LED to show we're alive
    static unsigned long lastBlink = 0;
    if (millis() - lastBlink > 1000) {
      digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
      lastBlink = millis();
    }
  }
}

// ===== WiFi and SmartConfig Management Functions =====

bool loadWiFiCredentials() {
  savedSSID = preferences.getString("ssid", "");
  savedPassword = preferences.getString("password", "");
  
  if (savedSSID.length() > 0) {
    Serial.printf("Loaded credentials: SSID='%s'\n", savedSSID.c_str());
    return true;
  }
  return false;
}

void saveWiFiCredentials(String ssid, String password) {
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  savedSSID = ssid;
  savedPassword = password;
  Serial.printf("Saved credentials: SSID='%s'\n", ssid.c_str());
}

void connectToWiFi() {
  if (savedSSID.length() > 0) {
    Serial.printf("Connecting to WiFi: %s\n", savedSSID.c_str());
    WiFi.begin(savedSSID.c_str(), savedPassword.c_str());
    
    // Wait up to 15 seconds for connection
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("\nFailed to connect to saved WiFi. Starting SmartConfig...");
      startSmartConfig();
    }
  } else {
    Serial.println("No saved credentials available");
    startSmartConfig();
  }
}

void startSmartConfig() {
  if (smartConfigActive) return;
  
  Serial.println("Starting SmartConfig...");
  Serial.println("Make sure your phone is connected to the WiFi network you want to configure!");
  
  // Try both SmartConfig types for better compatibility
  WiFi.beginSmartConfig(SC_TYPE_ESPTOUCH_AIRKISS);
  smartConfigActive = true;
  smartConfigStartTime = millis();
  
  Serial.println("SmartConfig started with ESP-Touch + AirKiss support");
  Serial.println("Open your Flutter app and start provisioning now!");
}

void stopSmartConfig() {
  if (!smartConfigActive) return;
  
  Serial.println("Stopping SmartConfig...");
  WiFi.stopSmartConfig();
  smartConfigActive = false;
}

void handleSmartConfig() {
  if (smartConfigActive) {
    // Check for timeout
    if (millis() - smartConfigStartTime > SMARTCONFIG_TIMEOUT) {
      Serial.println("SmartConfig timeout! Restarting SmartConfig...");
      stopSmartConfig();
      delay(1000);
      startSmartConfig();
      return;
    }

    // Check if SmartConfig has completed
    if (WiFi.smartConfigDone()) {
      Serial.println("SmartConfig: Got credentials via polling!");
      
      // Get the credentials that were just configured
      String ssid = WiFi.SSID();
      String password = WiFi.psk();
      
      Serial.printf("SmartConfig received - SSID: %s\n", ssid.c_str());
      
      // Save the new credentials
      saveWiFiCredentials(ssid, password);
      
      smartConfigActive = false;
      WiFi.stopSmartConfig();
      
      // Force a connection attempt with the new credentials  
      Serial.println("Attempting to connect with received credentials...");
      WiFi.begin(ssid.c_str(), password.c_str());
    } else {
      // Add some debug output to show SmartConfig is still listening
      static unsigned long lastDebug = 0;
      if (millis() - lastDebug > 15000) { // Every 15 seconds
        unsigned long elapsed = (millis() - smartConfigStartTime) / 1000;
        Serial.printf("SmartConfig: Still waiting for credentials... (%lu seconds elapsed)\n", elapsed);
        Serial.println("-> Ensure your phone and ESP32 are on the same 2.4GHz network during setup!");
        Serial.printf("-> WiFi Status: %d, SmartConfig Status: %s\n", 
                     WiFi.status(), WiFi.smartConfigDone() ? "Done" : "Waiting");
        lastDebug = millis();
      }
    }
  }
}

void startWebServer() {
  if (wifiConnected) {
    // ----- mDNS -----
    if (!MDNS.begin("circadian-light")) {
      Serial.println("Error starting mDNS");
    } else {
      Serial.println("mDNS responder started");
      MDNS.addService("_ws", "_tcp", 80);
    }
    
    // Set up WebSocket
    ws.onEvent(onWSMsg);
    server.addHandler(&ws);
    server.begin();
    
    Serial.println("WebSocket server started");
    Serial.printf("Connect to: ws://%s/ws\n", WiFi.localIP().toString().c_str());
  }
}