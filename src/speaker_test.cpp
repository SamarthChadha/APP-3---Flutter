// #include <WiFi.h>
// #include "AudioFileSourceHTTPStream.h"
// #include "AudioGeneratorWAV.h"
// #include "AudioOutputI2S.h"

// // Replace with your Wi-Fi credentials
// const char *ssid = "MAGS LAB";
// const char *password = "vXJC@(Lw";

// // Your GitHub-hosted .wav file (RAW link)
// const char *AUDIO_URL = "https://github.com/SamarthChadha/esp32-audio/blob/main/chirp.wav";

// // Audio objects
// AudioGeneratorWAV *wav;
// AudioFileSourceHTTPStream *file;
// AudioOutputI2S *out;

// void setup() {
//   Serial.begin(115200);

//   // Connect to Wi-Fi
//   WiFi.begin(ssid, password);
//   Serial.print("Connecting to WiFi");
//   while (WiFi.status() != WL_CONNECTED) {
//     delay(500);
//     Serial.print(".");
//   }
//   Serial.println("\nWiFi Connected!");

//   // Setup audio streaming
//   Serial.println("Trying to open WAV from:");
//   Serial.println(AUDIO_URL);
//   file = new AudioFileSourceHTTPStream(AUDIO_URL);
//   if (!file->isOpen()) {
//     Serial.println("FAILED to open WAV file from URL");
//   } else {
//     Serial.println("File opened successfully.");
//   }
//   out = new AudioOutputI2S(0, 1);          // Use I2S output (no internal DAC)
//   out->SetPinout(26, 25, 22);              // BCLK, LRCK, DIN
//   wav = new AudioGeneratorWAV();
//   wav->begin(file, out);                   // Start audio playback
// }

// void loop() {
//   if (wav->isRunning()) {
//     wav->loop();
//   } else {
//     file->seek(0, SEEK_SET);              // Rewind to beginning
//     wav->begin(file, out);                // Play again
//   }
// }