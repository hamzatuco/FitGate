include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>

// WiFi kredencijali
const char* ssid = "iPhone";
const char* password = "tulsaking";

// Firebase Cloud Function URL (europe-west1)
const char* firebaseUrl = "https://europe-west1-fitgate-iot.cloudfunctions.net/verifyLockerAccess";

// ID ovog ormarića (iz Firestore document ID)
const char* LOCKER_ID = "2FGYXSAkk3ip944zwzGs";

// RFID pinovi (prema tvojoj shemi)
#define RST_PIN 5   // GPIO5 (D1)
#define SS_PIN 4    // GPIO4 (D2)

// LED indikator
#define STATUS_LED 16  // GPIO16 (D0)

// Buzzer pin
#define BUZZER_PIN 15  // GPIO15 (D8)

MFRC522 rfid(SS_PIN, RST_PIN);
WiFiClientSecure client;

void setup() {
  Serial.begin(9600);
  
  // LED pin setup
  pinMode(STATUS_LED, OUTPUT);
  digitalWrite(STATUS_LED, LOW);
  
  // Buzzer pin setup
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  
  // RFID setup
  SPI.begin();
  rfid.PCD_Init();
  
  // WiFi konekcija
  Serial.println("Connecting to WiFi...");
  Serial.print("SSID: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 40) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n\n!!! WiFi CONNECTION FAILED !!!");
    Serial.println("Check:");
    Serial.println("1. iPhone hotspot is ON");
    Serial.println("2. Password is correct");
    Serial.println("3. iPhone is close to NodeMCU");
    while(1) {
      digitalWrite(STATUS_LED, HIGH);
      delay(200);
      digitalWrite(STATUS_LED, LOW);
      delay(200);
    }
  }
  
  Serial.println("\nWiFi connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  
  // Zvučni signal - WiFi OK
  tone(BUZZER_PIN, 1000, 200);
  delay(250);
  
  // Disable SSL certificate verification (za Firebase)
  client.setInsecure();
  
  // Test konekcija
  testConnection();
  
  Serial.println("Ready to scan RFID cards...");
}

void loop() {
  // Provjeri da li je kartica prisutna
  if (!rfid.PICC_IsNewCardPresent()) {
    return;
  }
  
  if (!rfid.PICC_ReadCardSerial()) {
    return;
  }
  
  // Pročitaj UID kartice
  String cardId = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    cardId += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
    cardId += String(rfid.uid.uidByte[i], HEX);
  }
  cardId.toUpperCase();

  // Kratki beep na skeniranje
  tone(BUZZER_PIN, 1200, 80);
  delay(90);

  Serial.println("\n==============================");
  Serial.print("[RFID] Kartica: ");
  Serial.println(cardId);
  Serial.println("------------------------------");
  // Verifikuj preko Firebase
  bool authorized = verifyAccess(cardId);
  if (authorized) {
    grantAccess();
  } else {
    denyAccess();
  }
  Serial.println("==============================\n");
  // Zaustavi čitanje
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  delay(2000);  // Pauza prije sljedećeg skeniranja
}

bool verifyAccess(String cardId) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected!");
    return false;
  }
  
  HTTPClient http;
  http.begin(client, firebaseUrl);
  http.addHeader("Content-Type", "application/json");
  
  // Kreiraj JSON payload
  StaticJsonDocument<200> doc;
  doc["cardId"] = cardId;
  doc["lockerId"] = LOCKER_ID;
  
  String payload;
  serializeJson(doc, payload);
  
  Serial.println("[API] → Šaljem zahtjev Firebase-u...");
  Serial.print("[API]   Payload: ");
  Serial.println(payload);
  int httpCode = http.POST(payload);
  if (httpCode > 0) {
    String response = http.getString();
    Serial.print("[API] ← Odgovor: ");
    Serial.println(httpCode);
    Serial.println("[API]   JSON:");
    // Lijepo formatiran JSON
    StaticJsonDocument<1024> prettyDoc;
    DeserializationError prettyErr = deserializeJson(prettyDoc, response);
    if (!prettyErr) {
      serializeJsonPretty(prettyDoc, Serial);
      Serial.println();
    } else {
      Serial.println(response); // fallback
    }
    // Prikaži samo bitne dijelove odgovora
    if (httpCode == 200) {
      StaticJsonDocument<512> responseDoc;
      DeserializationError error = deserializeJson(responseDoc, response);
      if (!error) {
        bool authorized = responseDoc["authorized"];
        String memberName = responseDoc["memberName"] | "Unknown";
        Serial.print("[API]   Status: ");
        if (authorized) {
          Serial.print("DOZVOLJEN | Korisnik: ");
          Serial.println(memberName);
          http.end();
          return true;
        } else {
          Serial.println("ODBIJEN");
        }
      } else {
        Serial.println("[API]   GRESKA: Ne mogu parsirati odgovor!");
      }
    } else {
      // Prikaži razlog odbijanja
      StaticJsonDocument<256> errDoc;
      DeserializationError err = deserializeJson(errDoc, response);
      String reason = errDoc["reason"] | "Nepoznat razlog";
      String code = errDoc["code"] | "";
      Serial.print("[API]   ODBIJENO: ");
      Serial.print(reason);
      if (code.length() > 0) {
        Serial.print(" (code: ");
        Serial.print(code);
        Serial.print(")");
      }
      Serial.println();
    }
  } else {
    Serial.print("[API]   HTTP Error: ");
    Serial.println(http.errorToString(httpCode));
  }
  http.end();
  return false;
}

void grantAccess() {
  Serial.println(">>> ACCESS GRANTED <<<");
  
  // Pozitivan zvuk - pristup odobren (duga nota, visok ton)
  tone(BUZZER_PIN, 2000, 500);
  
  // LED svijetli kontinuirano 5 sekundi
  digitalWrite(STATUS_LED, HIGH);
  delay(5000);
  digitalWrite(STATUS_LED, LOW);
  
  Serial.println("Locker unlocked for 5 seconds");
}

void denyAccess() {
  Serial.println(">>> ACCESS DENIED <<<");
  
  // Negativan zvuk - pristup odbijen (3x kratke note, nizak ton)
  for (int i = 0; i < 3; i++) {
    tone(BUZZER_PIN, 400, 150);
    delay(200);
  }
  
  // LED trepće brzo 5 puta
  for (int i = 0; i < 5; i++) {
    digitalWrite(STATUS_LED, HIGH);
    delay(150);
    digitalWrite(STATUS_LED, LOW);
    delay(150);
  }
}

void testConnection() {
  Serial.println("\nTesting Firebase connection...");
  
  HTTPClient http;
  String healthUrl = "https://europe-west1-fitgate-iot.cloudfunctions.net/healthCheck";
  
  http.begin(client, healthUrl);
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    Serial.println("✓ Firebase connection OK!");
    String response = http.getString();
    Serial.println(response);
    
    // Zvuk + 2x brzi blink - uspješna konekcija
    tone(BUZZER_PIN, 1500, 100);
    for (int i = 0; i < 2; i++) {
      digitalWrite(STATUS_LED, HIGH);
      delay(100);
      digitalWrite(STATUS_LED, LOW);
      delay(100);
    }
  } else {
    Serial.print("✗ Firebase connection failed: ");
    Serial.println(httpCode);
    
    // Greška zvuk + 5x brzi blink
    tone(BUZZER_PIN, 300, 500);
    for (int i = 0; i < 5; i++) {
      digitalWrite(STATUS_LED, HIGH);
      delay(100);
      digitalWrite(STATUS_LED, LOW);
      delay(100);
    }
  }
  
  http.end();
}
