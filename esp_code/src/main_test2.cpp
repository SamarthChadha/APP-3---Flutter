#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>

const char* SSID     = "MichaelPark-Guest";
const char* PASSWORD = "Steiner2021";

#define LED_BUILTIN 2   // builtin LED (GPIO2)
#define LED_A_PIN   16  // first LED group PWM (warm)
#define LED_B_PIN   17  // second LED group PWM (white)

#define ROTARY_DT  32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

const char* ESP_IP = "10.210.232.242";   // update if the ESP32 reboots with a new IP
const char* WS_URL = "ws://10.210.232.242/ws";

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");

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

  // two PWM channels, 8-bit duty
  ledcSetup(0, 5000, 4); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 4); ledcAttachPin(LED_B_PIN, 1);

  WiFi.begin(SSID, PASSWORD);
  Serial.print("WiFi…");
  while (WiFi.status() != WL_CONNECTED) delay(500);
  Serial.println(WiFi.localIP());

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
}