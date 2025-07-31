#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>
#include <DNSServer.h>
#include <ESPAsyncWiFiManager.h>
#include <EEPROM.h>

// const char* SSID     = "MAGS LAB";
// const char* PASSWORD = "vXJC@(Lw";

#define LED_BUILTIN 2   // builtin LED (GPIO2)  [oai_citation:15‡Circuits4You](https://circuits4you.com/2018/02/02/esp32-led-blink-example/?utm_source=chatgpt.com)
#define LED_A_PIN   16   // first LED group PWM
#define LED_B_PIN   17   // second LED group PWM

#define ROTARY_DT 32
#define ROTARY_CLK 33
#define ROTARY_BTN 25


bool shouldSaveConfig = false;
 
// Buffer for Wi-Fi credentials
char ssid[64];   // SSID up to 63 chars + NUL
char pass[64];   // WPA2 passphrase up to 63 chars + NUL

// Callback to save config after web server updates SSID and password
void saveConfigCallback() {
  Serial.println("Should save config");
  shouldSaveConfig = true;
}

// Save SSID and password to EEPROM
void saveCredentials(const char* newSSID, const char* newPass) {
  Serial.println("Saving WiFi credentials to EEPROM...");
  // Save SSID (64 bytes including NUL)
  for (int i = 0; i < 64; i++) {
    char c = (i < strlen(newSSID)) ? newSSID[i] : '\0';
    EEPROM.write(0 + i, c);
  }
  // Save Password (64 bytes including NUL)
  for (int i = 0; i < 64; i++) {
    char c = (i < strlen(newPass)) ? newPass[i] : '\0';
    EEPROM.write(100 + i, c);
  }
  EEPROM.commit();
}

// Read SSID and password from EEPROM
void readCredentials() {
  Serial.println("Reading WiFi credentials from EEPROM...");
  for (int i = 0; i < 64; i++) {
    ssid[i] = EEPROM.read(0 + i);
  }
  ssid[63] = '\0';
  for (int i = 0; i < 64; i++) {
    pass[i] = EEPROM.read(100 + i);
  }
  pass[63] = '\0';
  Serial.println("SSID: ");
  Serial.println(ssid);
  Serial.println("Password: ");
  Serial.println(pass);
  delay(5000);
}


const char* ESP_IP = "10.210.232.242";   // update if the ESP32 reboots with a new IP
const char* WS_URL = "ws://10.210.232.242/ws";

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");
// --- Serial Wi-Fi provisioning helpers ---
String readLine(uint32_t timeoutMs = 120000) {
  String s;
  uint32_t start = millis();
  while (millis() - start < timeoutMs) {
    while (Serial.available()) {
      char c = Serial.read();
      if (c == '\r') continue;
      if (c == '\n') return s;
      s += c;
    }
    delay(5);
  }
  return s; // may be empty on timeout
}

bool tryConnect(const char* s, const char* p, uint32_t timeoutMs = 20000) {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true, true);
  delay(200);
  Serial.printf("Connecting to '%s'...\n", s);
  WiFi.begin(s, (p && p[0]) ? p : nullptr);
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Connected! IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("Failed to connect.");
  return false;
}

void serialWifiProvision() {
  Serial.println();
  Serial.println("=== Wi-Fi Setup (Serial) ===");
  Serial.println("Scanning for networks...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(200);
  int n = WiFi.scanNetworks();
  if (n <= 0) {
    Serial.println("No networks found. Press ENTER to rescan.");
    readLine();
    n = WiFi.scanNetworks();
  }
  // List networks
  for (int i = 0, shown = 0; i < n; i++) {
    String ss = WiFi.SSID(i);
    if (ss.length() == 0) continue;
    shown++;
    Serial.printf("%2d) %s  (RSSI %d)%s\n", shown, ss.c_str(), WiFi.RSSI(i), WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? " [OPEN]" : "");
  }
  Serial.println("Enter the number of the network to use:");
  int choice = -1;
  while (choice < 1 || choice > n) {
    String line = readLine();
    choice = line.toInt();
    if (choice < 1) Serial.println("Please enter a valid number.");
  }
  // Map back to the chosen SSID by counting non-empty entries
  int index = -1, count = 0;
  for (int i = 0; i < n; i++) {
    if (WiFi.SSID(i).length() == 0) continue;
    count++;
    if (count == choice) { index = i; break; }
  }
  String selSsid = WiFi.SSID(index);
  bool needsPwd = WiFi.encryptionType(index) != WIFI_AUTH_OPEN;
  Serial.printf("Selected: %s\n", selSsid.c_str());
  String pwd;
  if (needsPwd) {
    Serial.println("Enter password (press ENTER for open networks):");
    pwd = readLine();
  }
  // Try connect
  if (tryConnect(selSsid.c_str(), needsPwd ? pwd.c_str() : "")) {
    saveCredentials(selSsid.c_str(), pwd.c_str());
    Serial.println("Credentials saved to EEPROM.");
  } else {
    Serial.println("Connection failed. Try again? (y/N)");
    String again = readLine();
    if (again.length() && (again[0] == 'y' || again[0] == 'Y')) serialWifiProvision();
  }
}

RotaryEncoder encoder(ROTARY_DT, ROTARY_CLK);
bool btnPressed = false;
int brightnessA = 128;
int brightnessB = 128;

unsigned long btnPressTime = 0;
bool isOn = true;
bool wasLongPress = false;
int longPressState = 0; // 0 = warm, 1 = both, 2 = white

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

  JsonDocument doc;           // ArduinoJson v7 – elastic capacity
  DeserializationError err = deserializeJson(doc, data, len);
  if (err) return;

  // if (doc["blink"].is<bool>() && doc["blink"].as<bool>()) {   // button pressed
  //   blinkBuiltin();
  // }
  if (doc["a"].is<int>()) {    // slider A
      Serial.printf("Slider A -> %d\n", doc["a"].as<int>());
    ledcWrite(0, doc["a"].as<int>());    // 0-255 duty
  }
  if (doc["b"].is<int>()) {    // slider B
      Serial.printf("Slider B -> %d\n", doc["b"].as<int>());
    ledcWrite(1, doc["b"].as<int>());
  }
}

void setup() {
  Serial.begin(115200);
  EEPROM.begin(512);  // Initialize EEPROM with 512 bytes
  pinMode(LED_BUILTIN, OUTPUT);
  
  // Read credentials before attempting WiFi connection
  readCredentials();
  
  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 8); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 8); ledcAttachPin(LED_B_PIN, 1);
  // Attempt to connect with stored credentials; if missing or fail, run serial setup
  bool hasStored = (ssid[0] != '\0');
  if (hasStored && tryConnect(ssid, pass)) {
    // connected
  } else {
    Serial.println("No valid saved credentials or connection failed.");
    Serial.println("\n>>> Open Serial Monitor at 115200, then follow prompts to set Wi‑Fi. <<<\n");
    serialWifiProvision();
  }

  // ----- mDNS (Step 5) -----
if (!MDNS.begin("circadian-light")) {          // hostname = circadian-light.local
  Serial.println("Error starting mDNS");
} else {
  Serial.println("mDNS responder started");
  MDNS.addService("_ws", "_tcp", 80);          // advertise the WebSocket port
}
// -------------------------

  ws.onEvent(onWSMsg);
  server.addHandler(&ws);
  server.begin();

  // encoder.begin(); // Removed: not needed for this RotaryEncoder library
  pinMode(ROTARY_BTN, INPUT_PULLUP);
}

void loop() { 
  static int lastPos = 0;
  encoder.tick();
  int newPos = encoder.getPosition();
  bool btnState = digitalRead(ROTARY_BTN) == LOW;

  if (newPos != lastPos) {
    int delta = newPos - lastPos;
    lastPos = newPos;

    if (!btnState) {
      // Normal turn
      if (delta > 0 && brightnessA < 255) {
        brightnessA = min(255, brightnessA + 5);
        brightnessB = min(255, brightnessB + 5);
      } else if (delta < 0 && brightnessA > 15) {
        brightnessA = max(15, brightnessA - 5);
        brightnessB = max(15, brightnessB - 5);
      }
    } else {
      // Button held down
      if (delta > 0) {
        brightnessA = max(0, brightnessA - 5);
        brightnessB = min(255, brightnessB + 5);
      } else if (delta < 0) {
        brightnessA = min(255, brightnessA + 5);
        brightnessB = max(0, brightnessB - 5);
      }
    }
    ledcWrite(0, brightnessA);
    ledcWrite(1, brightnessB);
    Serial.printf("Brightness A: %d, B: %d\n", brightnessA, brightnessB);
  }

  static bool lastBtnState = HIGH;
  bool currentBtnState = digitalRead(ROTARY_BTN);

  if (lastBtnState == HIGH && currentBtnState == LOW) {
    // button just pressed
    btnPressTime = millis();
    wasLongPress = false;
  }

  if (lastBtnState == LOW && currentBtnState == HIGH) {
    // button just released
    unsigned long pressDuration = millis() - btnPressTime;
    if (pressDuration >= 5000) {
      // WiFi setup (check this first)
      Serial.println("Entering Wi‑Fi setup over Serial...");
      serialWifiProvision();
    } else if (pressDuration >= 1500) {
      // Long press
      wasLongPress = true;
      longPressState = (longPressState + 1) % 3;
      if (longPressState == 0) {
        brightnessA = 255; brightnessB = 0; // warm
      } else if (longPressState == 1) {
        brightnessA = 255; brightnessB = 255; // both
      } else {
        brightnessA = 0; brightnessB = 255; // white
      }
      isOn = true;
      ledcWrite(0, brightnessA);
      ledcWrite(1, brightnessB);
      Serial.printf("Long press mode — A: %d, B: %d\n", brightnessA, brightnessB);
    } else if (pressDuration < 500) {
      // Short press = toggle light on/off
      isOn = !isOn;
      if (isOn) {
        ledcWrite(0, brightnessA);
        ledcWrite(1, brightnessB);
      } else {
        ledcWrite(0, 0);
        ledcWrite(1, 0);
      }
    }
  }

  lastBtnState = currentBtnState;

  ws.cleanupClients(); 
}