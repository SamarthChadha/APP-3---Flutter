// ESP32: set two PWM outputs to 100% duty
// Uses LEDC at 5 kHz, 8-bit (255 = 100%)

#include <esp32-hal-ledc.h>
#define LED_A_PIN 16   // your warm group
#define LED_B_PIN 17   // your white group

const int FREQ = 5000;       // 5 kHz
const int RES_BITS = 8;      // 8-bit resolution
const int CH_A = 0;
const int CH_B = 1;

void setup() {
  // Set up channels
  ledcSetup(CH_A, FREQ, RES_BITS);
  ledcSetup(CH_B, FREQ, RES_BITS);

  // Attach pins
  ledcAttachPin(LED_A_PIN, CH_A);
  ledcAttachPin(LED_B_PIN, CH_B);

  // 100% duty for 8-bit == 255
  ledcWrite(CH_A, 255);
  ledcWrite(CH_B, 255);
}

void loop() {
  // nothing to do—stays at full brightness
}