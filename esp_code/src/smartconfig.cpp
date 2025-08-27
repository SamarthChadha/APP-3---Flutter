// // SmartConfig for ESP32 (Arduino framework)
// // Replaces ESP-IDF example with Arduino-style setup()/loop().

// #include <Arduino.h>
// #include <WiFi.h>

// static void waitForSmartConfigAndConnect() {
//   Serial.println("[SC] Starting SmartConfig…");
//   WiFi.mode(WIFI_STA);
//   WiFi.beginSmartConfig();

//   // Wait until the phone app sends credentials
//   while (!WiFi.smartConfigDone()) {
//     Serial.print(".");
//     delay(500);
//   }
//   Serial.println("\n[SC] SmartConfig packet received.");

//   // Wait for WiFi to actually connect using received SSID/PASS
//   Serial.println("[WiFi] Connecting to AP…");
//   unsigned long start = millis();
//   while (WiFi.status() != WL_CONNECTED) {
//     // Try reconnecting if it takes too long
//     if (millis() - start > 15000) {
//       Serial.println("\n[WiFi] Still not connected, retrying…");
//       WiFi.reconnect();
//       start = millis();
//     }
//     delay(300);
//   }

//   Serial.print("[WiFi] Connected! SSID: ");
//   Serial.println(WiFi.SSID());
//   Serial.print("[WiFi] IP: ");
//   Serial.println(WiFi.localIP());
// }

// void setup() {
//   Serial.begin(115200);
//   delay(200);

//   // Start SmartConfig at boot. If credentials are already saved on the ESP32,
//   // it will connect quickly after SmartConfig completes.
//   waitForSmartConfigAndConnect();
// }

// void loop() {
//   // Keep the device online; if WiFi drops, go back into SmartConfig to allow
//   // re-provisioning from the phone.
//   if (WiFi.status() != WL_CONNECTED) {
//     Serial.println("[WiFi] Disconnected. Entering SmartConfig again…");
//     waitForSmartConfigAndConnect();
//   }

//   // Place your normal app work here
//   delay(1000);
// }