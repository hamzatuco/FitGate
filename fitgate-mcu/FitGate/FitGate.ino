#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Stepper.h>

// ===================== CONFIG =====================
const char* ssid = "iPhone";
const char* password = "tulsaking";
const char* firebaseUrlVerify = "https://europe-west1-fitgate-iot.cloudfunctions.net/verifyLockerAccess";
const char* firebaseUrlComplete = "https://europe-west1-fitgate-iot.cloudfunctions.net/completeLockerRequest";
const char* firebaseUrlHealth = "https://europe-west1-fitgate-iot.cloudfunctions.net/healthCheck";
const char* firestoreListUrl = "https://firestore.googleapis.com/v1/projects/fitgate-iot/databases/(default)/documents/lockerOpenRequests?pageSize=5&orderBy=requestedAt%20desc";
const char* LOCKER_ID = "2FGYXSAkk3ip944zwzGs";

// RC522: SS na D2, RST na 3V3
#define RC522_SS_PIN   4      // D2 GPIO4
#define RC522_RST_PIN  -1     // RST na 3V3

// LED + buzzer
#define STATUS_LED_PIN 5   // D1
#define BUZZER_PIN     5      // D1 GPIO5

// STEPPER (ULN2003) - BEZ TX, BEZ SPI konflikta
// IN1 -> D3 (GPIO0)
// IN2 -> D4 (GPIO2)
// IN3 -> D8 (GPIO15)
// IN4 -> RX (GPIO3)
#define ST_IN1 0              // D3
#define ST_IN2 2              // D4
#define ST_IN3 15             // D8
#define ST_IN4 3              // RX

const int STEPS_PER_REV = 2048;
const int MOTOR_RPM = 8;
const int UNLOCK_STEPS = 512;

const unsigned long POLL_INTERVAL_MS = 8000;
const unsigned long WIFI_RETRY_MS = 8000;
const unsigned long OPEN_HOLD_MS = 5000;
const unsigned long HTTP_TIMEOUT_MS = 5000;
const unsigned long RFID_RESET_INTERVAL_MS = 30000;

MFRC522 rfid(RC522_SS_PIN, RC522_RST_PIN);
WiFiClientSecure client;
Stepper stepperMotor(STEPS_PER_REV, ST_IN1, ST_IN3, ST_IN2, ST_IN4);

enum class LockerState : uint8_t { IDLE = 0, OPENING, HOLD_OPEN, CLOSING };
LockerState lockerState = LockerState::IDLE;

bool requestInProgress = false;
String lastHandledRequestId = "";
unsigned long stateStartedMs = 0, lastPollMs = 0, lastWiFiAttemptMs = 0, lastRfidResetMs = 0;

// ===================== UTIL =====================
String uidToHexUpper(const MFRC522::Uid &uid) {
  String s;
  s.reserve(uid.size * 2);
  for (byte i = 0; i < uid.size; i++) {
    if (uid.uidByte[i] < 0x10) s += "0";
    s += String(uid.uidByte[i], HEX);
  }
  s.toUpperCase();
  return s;
}

const bool LED_ACTIVE_LOW = true; // stavi false ako prevežeš LED da bude normalna (active-HIGH)

void ledOn()  { digitalWrite(STATUS_LED_PIN, LED_ACTIVE_LOW ? LOW  : HIGH); }
void ledOff() { digitalWrite(STATUS_LED_PIN, LED_ACTIVE_LOW ? HIGH : LOW ); }

// ===================== HTTP =====================
int httpRequest(const char* url, const String& payload = "", bool isPost = false) {
  if (WiFi.status() != WL_CONNECTED) return 0;
  HTTPClient http;
  http.begin(client, url);
  http.setTimeout(HTTP_TIMEOUT_MS);
  if (isPost) http.addHeader("Content-Type", "application/json");
  int code = isPost ? http.POST(payload) : http.GET();
  http.end();
  return code;
}

String httpPostString(const char* url, const String& payload) {
  if (WiFi.status() != WL_CONNECTED) return "";
  HTTPClient http;
  http.begin(client, url);
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(payload);
  String response = (code == 200) ? http.getString() : "";
  http.end();
  return response;
}

String httpGetString(const char* url) {
  if (WiFi.status() != WL_CONNECTED) return "";
  HTTPClient http;
  http.begin(client, url);
  http.setTimeout(HTTP_TIMEOUT_MS);
  int code = http.GET();
  String response = (code == 200) ? http.getString() : "";
  http.end();
  return response;
}

// ===================== FIREBASE =====================
bool verifyAccess(const String &cardId) {
  StaticJsonDocument<200> doc;
  doc["cardId"] = cardId;
  doc["lockerId"] = LOCKER_ID;

  String payload;
  serializeJson(doc, payload);

  String response = httpPostString(firebaseUrlVerify, payload);
  if (response.length() == 0) return false;

  StaticJsonDocument<512> resp;
  if (deserializeJson(resp, response) == DeserializationError::Ok) {
    bool authorized = resp["authorized"] | false;
    Serial.print("[API] ");
    Serial.println(authorized ? "YES" : "NO");
    return authorized;
  }
  return false;
}

void markLockerRequestCompleted(const String &requestId) {
  String payload = "{\"requestId\":\"" + requestId + "\"}";
  if (httpRequest(firebaseUrlComplete, payload, true) == 200) {
    Serial.println("[API] completed");
  }
}

// ===================== LOCKER =====================
void startUnlockSequence() {
  if (requestInProgress) return;
  requestInProgress = true;
  lockerState = LockerState::OPENING;
  stateStartedMs = millis();

  ledOn();
  tone(BUZZER_PIN, 1800, 120);
  unsigned long start = millis();
  while (millis() - start < 140) yield();

  Serial.println(">>> ACCESS GRANTED <<<");
}

void startDenySequence() {
  Serial.println(">>> ACCESS DENIED <<<");
  for (int i = 0; i < 3; i++) {
    tone(BUZZER_PIN, 400, 150);
    unsigned long start = millis();
    while (millis() - start < 220) yield();
  }
  for (int i = 0; i < 5; i++) {
    ledOn();
    unsigned long start = millis();
    while (millis() - start < 120) yield();
    ledOff();
    start = millis();
    while (millis() - start < 120) yield();
  }
}

void motorRelease() {
  digitalWrite(ST_IN1, LOW);
  digitalWrite(ST_IN2, LOW);
  digitalWrite(ST_IN3, LOW);
  digitalWrite(ST_IN4, LOW);
}

void motorStep(int steps) {
  stepperMotor.setSpeed(MOTOR_RPM);

  int dir = (steps >= 0) ? 1 : -1;
  int count = abs(steps);

  for (int i = 0; i < count; i++) {
    stepperMotor.step(dir); // 1 korak
    yield();                // sprijeci WDT reset
    ESP.wdtFeed();
  }

  motorRelease();
}


void tickLockerStateMachine() {
  unsigned long now = millis();
  switch (lockerState) {
    case LockerState::IDLE: return;

    case LockerState::OPENING:
      motorStep(+UNLOCK_STEPS);
      lockerState = LockerState::HOLD_OPEN;
      stateStartedMs = now;
      return;

    case LockerState::HOLD_OPEN:
      if (now - stateStartedMs >= OPEN_HOLD_MS) {
        lockerState = LockerState::CLOSING;
        stateStartedMs = now;
      }
      return;

    case LockerState::CLOSING:
      motorStep(-UNLOCK_STEPS);
      ledOff();
      lockerState = LockerState::IDLE;
      requestInProgress = false;

      // PATCH: nakon motora “osvježi” RFID (pomaže u praksi)
      SPI.begin();
      rfid.PCD_Init();
      rfid.PCD_StopCrypto1();

      Serial.println(">>> DONE <<<");
      return;
  }
}

// ===================== POLLING =====================
void pollLockerOpenRequests() {
  if (WiFi.status() != WL_CONNECTED || requestInProgress) return;

  String response = httpGetString(firestoreListUrl);
  if (response.length() == 0) return;

  StaticJsonDocument<4096> doc;
  if (deserializeJson(doc, response) != DeserializationError::Ok) return;

  for (JsonObject d : doc["documents"].as<JsonArray>()) {
    if ((String)d["fields"]["lockerId"]["stringValue"] != LOCKER_ID) continue;
    if ((String)d["fields"]["status"]["stringValue"] != "pending") continue;

    String docName = d["name"].as<String>();
    int lastSlash = docName.lastIndexOf('/');
    String requestId = lastSlash >= 0 ? docName.substring(lastSlash + 1) : "";

    if (requestId.length() == 0 || requestId == lastHandledRequestId) continue;

    lastHandledRequestId = requestId;
    Serial.println("[API] open request");

    markLockerRequestCompleted(requestId);
    startUnlockSequence();
    break;
  }
}

// ===================== WIFI =====================
void ensureWiFiConnected() {
  if (WiFi.status() == WL_CONNECTED) return;
  unsigned long now = millis();
  if (now - lastWiFiAttemptMs < WIFI_RETRY_MS) return;
  lastWiFiAttemptMs = now;
  WiFi.begin(ssid, password);
}

// ===================== RFID =====================
void resetRfidIfNeeded() {
  unsigned long now = millis();
  if (now - lastRfidResetMs < RFID_RESET_INTERVAL_MS) return;
  lastRfidResetMs = now;
  rfid.PCD_Init();
  yield();
}

// ===================== SETUP =====================
void setup() {
  Serial.begin(9600);
  delay(50);


  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  ledOff();

  pinMode(ST_IN1, OUTPUT);
  pinMode(ST_IN2, OUTPUT);
  pinMode(ST_IN3, OUTPUT);
  pinMode(ST_IN4, OUTPUT);
  motorRelease();

  SPI.begin();
  rfid.PCD_Init();

  client.setInsecure();
  client.setTimeout(HTTP_TIMEOUT_MS);

  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) {
    delay(300);
    Serial.print(".");
    ESP.wdtFeed();
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("\nWiFi: ");
    Serial.println(WiFi.localIP());
    if (httpRequest(firebaseUrlHealth) == 200) Serial.println("Firebase OK");
  } else {
    Serial.println("\n[WiFi] retry in loop");
  }

  Serial.println("Ready...");
  lastRfidResetMs = millis();
}

// ===================== LOOP =====================
void loop() {
  ESP.wdtFeed();

  ensureWiFiConnected();
  tickLockerStateMachine();
  resetRfidIfNeeded();

  if (!requestInProgress && rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String cardId = uidToHexUpper(rfid.uid);

    tone(BUZZER_PIN, 1200, 80);
    unsigned long start = millis();
    while (millis() - start < 90) yield();

    Serial.print("[RFID] Kartica: ");
    Serial.println(cardId);

    bool authorized = verifyAccess(cardId);
    if (authorized) startUnlockSequence();
    else startDenySequence();

    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();

    start = millis();
    while (millis() - start < 200) yield();
  }

  unsigned long now = millis();
  if (now - lastPollMs >= POLL_INTERVAL_MS) {
    lastPollMs = now;
    pollLockerOpenRequests();
  }

  yield();
}
