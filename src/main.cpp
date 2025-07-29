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
char ssid[32];
char pass[32];

// Callback to save config after web server updates SSID and password
void saveConfigCallback() {
  Serial.println("Should save config");
  shouldSaveConfig = true;
}

// Save SSID and password to EEPROM
void saveCredentials(const char* newSSID, const char* newPass) {
Serial.println("Saving WiFi credentials to EEPROM...");

// Save SSID
for (int i = 0; i < 32; i++) {
  EEPROM.write(0 + i, newSSID[i]);
}
// Save Password
for (int i = 0; i < 32; i++) {
  EEPROM.write(100 + i, newPass[i]);
}
EEPROM.commit();
}

// Read SSID and password from EEPROM
void readCredentials() {
  Serial.println("Reading WiFi credentials from EEPROM...");
  
  for (int i = 0; i < 32; i++) {
    ssid[i] = EEPROM.read(0 + i);
  }
  ssid[31] = '\0';
 
  for (int i = 0; i < 32; i++) {
    pass[i] = EEPROM.read(100 + i);
  }
  pass[31] = '\0';
 
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
DNSServer dns;
AsyncWiFiManager wm(&server, &dns);

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
  
  wm.setSaveConfigCallback(saveConfigCallback);
  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 8); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 8); ledcAttachPin(LED_B_PIN, 1);

  WiFi.begin(ssid, pass);
  Serial.print("WiFi…");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed, starting config portal");
    wm.startConfigPortal("Circadian_WiFi_Config");
  }
  // TEMP: Force WiFi setup portal on boot for testing
  // Remove this line after testing
  wm.startConfigPortal("Circadian_WiFi_Config");

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
      Serial.println("Button pressed, starting WiFiManager...");
      wm.startConfigPortal("Circadian_WiFi_Config");
      if (shouldSaveConfig) {
        saveCredentials(WiFi.SSID().c_str(), WiFi.psk().c_str());
        Serial.println("Credentials saved.");
        ESP.restart();
      }
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