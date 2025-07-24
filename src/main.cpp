#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>
#include <WiFiManager.h>
#include <EEPROM.h>

// const char* SSID     = "MAGS LAB";
// const char* PASSWORD = "vXJC@(Lw";

#define LED_BUILTIN 2   // builtin LED (GPIO2)  [oai_citation:15‡Circuits4You](https://circuits4you.com/2018/02/02/esp32-led-blink-example/?utm_source=chatgpt.com)
#define LED_A_PIN   16   // first LED group PWM
#define LED_B_PIN   17   // second LED group PWM

#define ROTARY_DT 32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

WiFiManager wm;

bool shouldSaveConfig = false;
 
// Buffer for Wi-Fi credentials
char ssid[32];
char pass[32];




const char* ESP_IP = "10.210.232.242";   // update if the ESP32 reboots with a new IP
const char* WS_URL = "ws://10.210.232.242/ws";

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");

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
  pinMode(LED_BUILTIN, OUTPUT);

  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 8); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 8); ledcAttachPin(LED_B_PIN, 1);

  WiFi.begin(SSID, PASSWORD);
  Serial.print("WiFi…");
  while (WiFi.status() != WL_CONNECTED) delay(500);
  Serial.println(WiFi.localIP());

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
    if (pressDuration < 500) {
      // short press = toggle light on/off
      isOn = !isOn;
      if (isOn) {
        ledcWrite(0, brightnessA);
        ledcWrite(1, brightnessB);
      } else {
        ledcWrite(0, 0);
        ledcWrite(1, 0);
      }
    } else if (pressDuration >= 1500) {
      // long press
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
    }
  }

  lastBtnState = currentBtnState;

  ws.cleanupClients(); 
}