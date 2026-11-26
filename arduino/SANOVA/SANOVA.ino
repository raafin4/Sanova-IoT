#include <ESP32Servo.h>
#include "HX711.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// GPIO ESP32
#define ULTRA_TRIG 27
#define ULTRA_ECHO 26
#define OLED_SCL 22
#define OLED_SDA 21
#define BUZZER_PIN 18
#define SERVO_TRASH 33
#define SERVO_TISSUE 32
#define PROX_TRASH 34
#define PROX_TISSUE 35
#define LED_TRASH 4
#define LED_TISSUE 2
#define HX_DT 19
#define HX_SCK 23

//SSID & Password WiFi
const char* ssid = "XXXXXXXXXXX";
const char* password = "XXXXXXXXXXX";
WebServer server(80);

// Konfigurasi Server Monitoring
const char* serverURL = "https://sanova.my.id/api.php"; // Ganti dengan domain Anda
const char* deviceID = "SANOVA_001"; // ID unik untuk device ini

// Objek
Servo servoTrash;
Servo servoTissue;
HX711 scale;

// Struktur dan Status
struct Device {
  const char* name;
  int proxPin;
  Servo* servo;
  bool active = false;
  unsigned long timeout = 0;
  unsigned long countdownStart = 0;
  int lastDisplayedSec = -1;
  int xCountdown;  // posisi X untuk tampilan countdown OLED
};

Device trash = { "Trash", PROX_TRASH, &servoTrash, false, 0, 0, -1, 0 };
Device tissue = { "Tissue", PROX_TISSUE, &servoTissue, false, 0, 0, -1, 80 };

// OLED Display SH1106
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SH1106G display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1); // Ganti objek OLED

//Logika Ultrasonic Stock Tissue
#define JARAK_MAKSIMUM 42.0  // cm (tisu habis / kosong)
#define JARAK_MINIMUM 7.0    // cm (tisu penuh)
#define AMBANG_HABIS 65.0    // persen, ambang batas tisu habis

// Konfigurasi
const float kapasitasMaks = 500.0;
const float skalaKalibrasi = 422.4f;
float berat = 0;

// Variabel untuk monitoring
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 30000; // Kirim data setiap 30 detik
bool wifiConnected = false;

// Bitmap ikon kotak tisu
const unsigned char epd_bitmap_ikon_kotak_tisu_48x48pix_ [] PROGMEM = {
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00, 0x01, 0xff, 0xc0, 0x00, 0x00, 0x07, 
	0xff, 0x00, 0x60, 0x00, 0x00, 0x03, 0x60, 0x00, 0x40, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 
	0x00, 0x01, 0x84, 0x21, 0x80, 0x00, 0x00, 0x00, 0x84, 0x21, 0x00, 0x00, 0x00, 0x1f, 0xc4, 0x23, 
	0xf8, 0x00, 0x00, 0x10, 0x66, 0x66, 0x08, 0x00, 0x00, 0x20, 0x22, 0x44, 0x04, 0x00, 0x00, 0x20, 
	0x72, 0x4e, 0x04, 0x00, 0x00, 0x20, 0x52, 0x4a, 0x04, 0x00, 0x00, 0x60, 0x7f, 0xfe, 0x06, 0x00, 
	0x00, 0x40, 0x00, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x00, 0x02, 0x00, 0x00, 0xff, 0xff, 0xff, 
	0xff, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 
	0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 
	0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0xc0, 0x00, 0x00, 
	0x03, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x7f, 0xff, 0xff, 0xfe, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// Bitmap ikon tempat sampah
const unsigned char epd_bitmap_ikon_tempat_sampah_48x48pix_ [] PROGMEM = {
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1f, 0xf8, 
	0x00, 0x00, 0x00, 0x00, 0x10, 0x08, 0x00, 0x00, 0x00, 0x03, 0xff, 0xff, 0xc0, 0x00, 0x00, 0x0f, 
	0xef, 0xf7, 0xf0, 0x00, 0x00, 0x08, 0x00, 0x00, 0x10, 0x00, 0x00, 0x08, 0x00, 0x00, 0x10, 0x00, 
	0x00, 0x08, 0x00, 0x00, 0x10, 0x00, 0x00, 0x07, 0xff, 0xff, 0xe0, 0x00, 0x00, 0x02, 0x00, 0x00, 
	0xc0, 0x00, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x00, 0x02, 
	0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 
	0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 
	0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 
	0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 
	0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x11, 0x88, 0x40, 0x00, 0x00, 0x02, 0x00, 0x00, 
	0x40, 0x00, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x00, 0x00, 0x01, 
	0xff, 0xff, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// Fungsi untuk kirim data ke server (hanya persentase tisu dan sampah)
void sendDataToServer(float tissuePercent, float trashPercent) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi tidak terhubung, tidak bisa kirim data");
    return;
  }

  HTTPClient http;
  http.begin(serverURL);
  http.addHeader("Content-Type", "application/json");

  // Buat JSON data - hanya persentase tisu dan sampah
  DynamicJsonDocument doc(512);  // Ukuran lebih kecil karena data lebih sedikit
  doc["device_id"] = deviceID;
  doc["tissue_percent"] = tissuePercent;
  doc["trash_percent"] = trashPercent;
  doc["timestamp"] = millis(); // Bisa diganti dengan RTC jika ada

  String jsonString;
  serializeJson(doc, jsonString);

  Serial.println("📤 Mengirim data ke server:");
  Serial.println(jsonString);

  int httpResponseCode = http.POST(jsonString);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.printf("✅ Data terkirim! Response code: %d\n", httpResponseCode);
    Serial.println("Response: " + response);
  } else {
    Serial.printf("❌ Error mengirim data! Error code: %d\n", httpResponseCode);
  }

  http.end();
}

// Fungsi cek koneksi WiFi
void checkWiFiConnection() {
  if (WiFi.status() != WL_CONNECTED && wifiConnected) {
    Serial.println("❌ WiFi terputus! Mencoba reconnect...");
    wifiConnected = false;
  } else if (WiFi.status() == WL_CONNECTED && !wifiConnected) {
    Serial.println("✅ WiFi terhubung kembali!");
    Serial.println("IP Address: " + WiFi.localIP().toString());
    wifiConnected = true;
  }
}

void setup() {
  Serial.begin(115200);

  // Setup pin
  pinMode(PROX_TISSUE, INPUT);
  pinMode(PROX_TRASH, INPUT);

  pinMode(ULTRA_TRIG, OUTPUT);
  pinMode(ULTRA_ECHO, INPUT);

  pinMode(LED_TISSUE, OUTPUT);
  pinMode(LED_TRASH, OUTPUT);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(LED_TISSUE, LOW);
  digitalWrite(LED_TRASH, LOW);
  digitalWrite(BUZZER_PIN, LOW);

  //WiFi Setup
  WiFi.begin(ssid, password);
  Serial.println("🔄 Menghubungkan ke WiFi...");
  
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(1000);
    Serial.print(".");
    wifiAttempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ Terhubung ke WiFi!");
    Serial.println("📍 IP Address: " + WiFi.localIP().toString());
    wifiConnected = true;
  } else {
    Serial.println("\n❌ Gagal terhubung ke WiFi!");
    wifiConnected = false;
  }

  // Servo
  servoTissue.attach(SERVO_TISSUE);
  servoTrash.attach(SERVO_TRASH);
  servoTissue.write(0);
  servoTrash.write(0);

  // Load Cell
  scale.begin(HX_DT, HX_SCK);
  scale.set_scale(skalaKalibrasi);
  scale.tare();
  Serial.println("⚖️ Menunggu load cell stabil...");
  delay(2000);

  // OLED
  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(0x3C, true)) {  // true untuk reset internal
    Serial.println("⚠️ Gagal inisialisasi OLED SH1106");
    while (1);
  }
  display.clearDisplay();
  display.drawBitmap(0, 0, epd_bitmap_ikon_kotak_tisu_48x48pix_, 48, 48, SH110X_WHITE);
  display.drawBitmap(80, 0, epd_bitmap_ikon_tempat_sampah_48x48pix_, 48, 48, SH110X_WHITE);
  display.display();
  delay(1000);

  Serial.println("🚀 SANOVA Terintegrasi dengan Monitoring Siap ✅");
  
  // Kirim data awal
  if (wifiConnected) {
    sendDataToServer(100.0, 0.0);  // tissue 100%, trash 0%
  }
}

void loop() {
  unsigned long sekarang = millis();
  
  // Cek koneksi WiFi
  checkWiFiConnection();
  
  // Handle proximity sensors
  handleProximity(trash, sekarang);
  handleProximity(tissue, sekarang);

  // --- Sensor Ultrasonik ---
  float jarakTisu = bacaUltrasonik();
  // Hitung persentase ketinggian tisu
  float persenTisu = ((JARAK_MAKSIMUM - jarakTisu) / (JARAK_MAKSIMUM - JARAK_MINIMUM)) * 100.0;
  // Batasi nilai agar tidak lebih dari 100% atau kurang dari 0%
  persenTisu = constrain(persenTisu, 0, 100);
  bool tissueEmpty = (persenTisu <= (100 - AMBANG_HABIS));  // Jika kurang dari 25% isi
  
  if (tissueEmpty) {
    Serial.print("⚠️ Tisu habis. Ketinggian saat ini: ");
    Serial.print(jarakTisu);
    Serial.println(" cm");
    digitalWrite(LED_TISSUE, HIGH);
  } else {
    Serial.print("📏 Ketinggian tisu: ");
    Serial.print(jarakTisu);
    Serial.println(" cm");
    digitalWrite(LED_TISSUE, LOW);
  }

  // --- Load Cell ---
  const float beratKeranjang = 370.0;
  berat = scale.get_units(5);
  berat -= beratKeranjang;
  if (berat < 0.0) berat = 0.0;
  if (berat < 1.0) berat = 0;
  float persen = (berat / kapasitasMaks) * 100.0;
  if (persen > 100.0) persen = 100.0;

  Serial.print("📦 Sampah: ");
  Serial.print(berat);
  Serial.print("g (");
  Serial.print(persen);
  Serial.println("%)");

  bool trashFull = (persen >= 75.0);
  if (trashFull) {
    digitalWrite(LED_TRASH, HIGH);
    Serial.println("🚨 Sampah hampir penuh!");
  } else {
    digitalWrite(LED_TRASH, LOW);
  }

  // --- Kirim Data ke Server ---
  if (wifiConnected && (sekarang - lastSendTime >= sendInterval)) {
    sendDataToServer(persenTisu, persen);
    lastSendTime = sekarang;
  }


  server.handleClient();
}

float bacaUltrasonik() {
  digitalWrite(ULTRA_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(ULTRA_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(ULTRA_TRIG, LOW);

  long durasi = pulseIn(ULTRA_ECHO, HIGH);
  return (durasi * 0.0343) / 2;
}

void moveServoSmooth(Servo &servo, int from, int to, int stepDelay = 10) {
  if (from < to) {
    for (int pos = from; pos <= to; pos++) {
      servo.write(pos);
      delay(stepDelay);
    }
  } else {
    for (int pos = from; pos >= to; pos--) {
      servo.write(pos);
      delay(stepDelay);
    }
  }
}

void handleProximity(Device &dev, unsigned long now) {
  if (digitalRead(dev.proxPin) == LOW && !dev.active) {
    Serial.printf("🖐️ Deteksi pada %s\n", dev.name);
    moveServoSmooth(*dev.servo, 0, 90);  // buka halus
    dev.timeout = now + 10000;  // 10 detik terbuka
    dev.countdownStart = now;
    dev.lastDisplayedSec = -1;
    dev.active = true;
  }

  if (dev.active) {
    int sisaDetik = 10 - ((now - dev.countdownStart) / 1000);
    if (sisaDetik != dev.lastDisplayedSec && sisaDetik >= 0) {
      dev.lastDisplayedSec = sisaDetik;

      // OLED
      display.fillRect(dev.xCountdown, 50, 48, 14, SH110X_BLACK);
      display.setTextSize(1);
      display.setTextColor(SH110X_WHITE);
      int textWidth = (sisaDetik < 10) ? 6 : 12;
      int xText = dev.xCountdown + (48 - textWidth) / 2;
      display.setCursor(xText, 52);
      display.print(sisaDetik);
      display.display();

      // Buzzer beep di 3 detik terakhir
      if (sisaDetik <= 3) {
        digitalWrite(BUZZER_PIN, HIGH);
        delay(100);
        digitalWrite(BUZZER_PIN, LOW);
      }
    }

    if (now >= dev.timeout) {
      moveServoSmooth(*dev.servo, 90, 0);  // tutup halus
      Serial.printf("🔒 %s menutup\n", dev.name);
      dev.active = false;

      // Bersihkan OLED
      display.fillRect(dev.xCountdown, 50, 48, 14, SH110X_BLACK);
      display.display();
    }
  }
}