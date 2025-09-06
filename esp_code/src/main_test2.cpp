// Core Arduino / networking
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <RotaryEncoder.h>

// Low‑level ESP-IDF headers for native SmartConfig (from smartconfig.cpp example)
extern "C" {
  #include "freertos/FreeRTOS.h"
  #include "freertos/task.h"
  #include "freertos/event_groups.h"
  #include "esp_wifi.h"
  #include "esp_event.h"
  #include "esp_smartconfig.h"
  #include "esp_system.h"
  #include "esp_netif.h"
  #include "nvs_flash.h"
  #include "esp_log.h"
  #include "esp_mac.h"
}

// Remove hardcoded credentials - will be provided via SmartConfig
// const char* SSID     = "MAGS LAB";
// const char* PASSWORD = "vXJC@(Lw";

#define LED_BUILTIN 2   // builtin LED (GPIO2)
#define LED_A_PIN   16  // first LED group PWM (warm)
#define LED_B_PIN   17  // second LED group PWM (white)

#define ROTARY_DT  32
#define ROTARY_CLK 33
#define ROTARY_BTN 25

// SmartConfig / WiFi state
static EventGroupHandle_t wifiEventGroup;
static const int CONNECTED_BIT = BIT0;
static const int ESPTOUCH_DONE_BIT = BIT1;
static volatile bool wifiConnected = false; // mirror of CONNECTED_BIT for Arduino logic

// Tag for logging (uses ESP_LOGx macros)
static const char *SC_TAG = "SC";

// Create AsyncWebServer instance on port 80
AsyncWebServer server(80);
// Create AsyncWebSocket instance
AsyncWebSocket ws("/ws");

// Forward declarations
void startWebServer();
static void smartconfigTask(void *param);
static void nativeEventHandler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data);

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

  // PWM channels
  ledcSetup(0, 5000, 4); ledcAttachPin(LED_A_PIN, 0);
  ledcSetup(1, 5000, 4); ledcAttachPin(LED_B_PIN, 1);

  // Initialize NVS (in case not already done by Arduino core)
  if (nvs_flash_init() != ESP_OK) {
    Serial.println("NVS init failed");
  }

  // Ensure esp-netif/event loop ready (Arduino normally does this but harmless)
  esp_netif_init();
  esp_event_loop_create_default();
  esp_netif_create_default_wifi_sta();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  esp_wifi_init(&cfg);
  esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &nativeEventHandler, NULL);
  esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &nativeEventHandler, NULL);
  esp_event_handler_register(SC_EVENT, ESP_EVENT_ANY_ID, &nativeEventHandler, NULL);
  esp_wifi_set_mode(WIFI_MODE_STA);
  esp_wifi_start();

  wifiEventGroup = xEventGroupCreate();

  // Start SmartConfig task (native ESP-IDF style)
  xTaskCreatePinnedToCore(smartconfigTask, "smartconfig", 4096, NULL, 3, NULL, APP_CPU_NUM);

  // Input pins
  pinMode(ROTARY_BTN, INPUT_PULLUP);
  int idle = digitalRead(ROTARY_BTN);
  Serial.printf("ROTARY_BTN idle read: %d (expect %s when unpressed)\n", idle, BUTTON_ACTIVE_LOW ? "HIGH" : "LOW");

  applyOutput();
}

void loop() {
  // Update cached wifiConnected flag from event group
  if (wifiEventGroup) {
    EventBits_t bits = xEventGroupGetBits(wifiEventGroup);
    wifiConnected = bits & CONNECTED_BIT;
  }

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
// ===== Native SmartConfig adaptation (ESP-IDF style) =====

static void smartconfigTask(void *param) {
  // Set type (ESP-Touch by default; could OR with SC_TYPE_AIRKISS)
  esp_smartconfig_set_type(SC_TYPE_ESPTOUCH);
  smartconfig_start_config_t cfg = SMARTCONFIG_START_CONFIG_DEFAULT();
  esp_smartconfig_start(&cfg);
  Serial.println("[SC] SmartConfig task started – use Flutter app to provision.");
  Serial.println("[SC] Listening for SmartConfig packets...");
  Serial.printf("[SC] MAC Address: %s\n", WiFi.macAddress().c_str());
  
  // Add periodic status updates
  unsigned long lastStatus = 0;
  while (true) {
    // Print status every 10 seconds
    if (millis() - lastStatus > 10000) {
      Serial.println("[SC] Still waiting for SmartConfig packets from Flutter app...");
      lastStatus = millis();
    }
    
    EventBits_t bits = xEventGroupWaitBits(
        wifiEventGroup,
        CONNECTED_BIT | ESPTOUCH_DONE_BIT,
        pdTRUE,
        pdFALSE,
        pdMS_TO_TICKS(1000)); // Wait max 1 second before checking status again
    if (bits & CONNECTED_BIT) {
      Serial.println("[SC] WiFi Connected to AP");
      // Start web server once upon first connection
      startWebServer();
    }
    if (bits & ESPTOUCH_DONE_BIT) {
      Serial.println("[SC] SmartConfig provisioning complete");
      esp_smartconfig_stop();
      vTaskDelete(NULL);
    }
  }
}

static void nativeEventHandler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
    // Launch SmartConfig task (already started in setup, keep as safeguard)
  } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
    esp_wifi_connect();
    if (wifiEventGroup) xEventGroupClearBits(wifiEventGroup, CONNECTED_BIT);
  } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
    if (wifiEventGroup) xEventGroupSetBits(wifiEventGroup, CONNECTED_BIT);
    Serial.printf("[SC] Got IP: %s\n", WiFi.localIP().toString().c_str());
  } else if (event_base == SC_EVENT && event_id == SC_EVENT_SCAN_DONE) {
    ESP_LOGI(SC_TAG, "Scan done");
  } else if (event_base == SC_EVENT && event_id == SC_EVENT_FOUND_CHANNEL) {
    ESP_LOGI(SC_TAG, "Found channel");
  } else if (event_base == SC_EVENT && event_id == SC_EVENT_GOT_SSID_PSWD) {
    ESP_LOGI(SC_TAG, "Got SSID and password");
    smartconfig_event_got_ssid_pswd_t *evt = (smartconfig_event_got_ssid_pswd_t *)event_data;
    wifi_config_t wifi_config;
    memset(&wifi_config, 0, sizeof(wifi_config));
    memcpy(wifi_config.sta.ssid, evt->ssid, sizeof(wifi_config.sta.ssid));
    memcpy(wifi_config.sta.password, evt->password, sizeof(wifi_config.sta.password));
#ifdef CONFIG_SET_MAC_ADDRESS_OF_TARGET_AP
    wifi_config.sta.bssid_set = evt->bssid_set;
    if (wifi_config.sta.bssid_set) memcpy(wifi_config.sta.bssid, evt->bssid, 6);
#endif
    Serial.printf("[SC] SSID: %s\n", (char*)wifi_config.sta.ssid);
    Serial.printf("[SC] PASSWORD: %s\n", (char*)wifi_config.sta.password);
    esp_wifi_disconnect();
    esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
    esp_wifi_connect();
  } else if (event_base == SC_EVENT && event_id == SC_EVENT_SEND_ACK_DONE) {
    ESP_LOGI(SC_TAG, "SmartConfig ACK done");
    if (wifiEventGroup) xEventGroupSetBits(wifiEventGroup, ESPTOUCH_DONE_BIT);
  }
}

void startWebServer() {
  if (!wifiConnected) return;
  static bool started = false;
  if (started) return;
  started = true;
  if (!MDNS.begin("circadian-light")) {
    Serial.println("Error starting mDNS");
  } else {
    Serial.println("mDNS responder started");
    MDNS.addService("_ws", "_tcp", 80);
  }
  ws.onEvent(onWSMsg);
  server.addHandler(&ws);
  server.begin();
  Serial.printf("WebSocket server started at ws://%s/ws\n", WiFi.localIP().toString().c_str());
}
