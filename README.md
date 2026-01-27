# FitGate — IoT Locker & Access System (Entrio-style)
FitGate is a smart IoT-based access control and locker management system for gyms and fitness centers. It enables RFID/NFC member identification, automatic membership validation, real-time access logging, and centralized management of users and lockers through an integrated mobile and backend platform. Flutter Firebase

The system components:

- ESP8266 MCU firmware (RFID reader, stepper lock control, ultrasonic sensor)
- Firebase Cloud Functions (verify, open, complete, notifications)
- Flutter apps: `apps/fitgate_client` (member) and `apps/fitgate_admin` (staff)
- Shared Dart models in `shared/fitgate_shared`

---

## 1️⃣ Authoritative Pin Mapping (ESP8266)

Match these pins to `fitgate-mcu/FitGate/FitGate.ino` (single source of truth).

### RC522 RFID (SPI)

| ESP8266 (D..) | GPIO | RC522 pin | Purpose |
|--------------:|:----:|:---------|:-------|
| D2           | GPIO4 | SDA / SS  | Chip select (RC522 SS)
| -            | -     | RST       | tied to 3.3V (no reset pin)
| 3V3          | -     | VCC       | Power (3.3V ONLY)
| GND          | -     | GND       | Ground

### LEDs & Buzzer

| Name | ESP8266 pin | Purpose |
|------|-------------|--------|
| STATUS_LED_PIN | D1 (GPIO5) | Status LED (active-low by default)
| BUZZER_PIN     | D1 (GPIO5) | Buzzer (shares pin)

### Stepper (28BYJ-48 via ULN2003)

| MCU label | ESP8266 pin | Board pin |
|-----------|-------------|----------|
| ST_IN1    | D3 (GPIO0)  | IN1
| ST_IN2    | D4 (GPIO2)  | IN2
| ST_IN3    | D8 (GPIO15) | IN3
| ST_IN4    | RX (GPIO3)  | IN4

Power: ULN2003 VCC → external 5V (VIN/USB), ULN2003 GND → ESP GND (common ground)

### Ultrasonic HC-SR04

| Signal | ESP8266 pin |
|--------|-------------|
| TRIG   | (configurable) — used in firmware polling
| ECHO   | (read via voltage divider) — do NOT connect 5V directly to ESP GPIO

In firmware this board polls Firestore and also uses ultrasonic readings to stop/hold the motor while closing.

---

## 2️⃣ Cloud endpoints & data model (quick)

- `verifyLockerAccess` (HTTPS) — used by MCU when an RFID is presented. Validates card, membership and locker assignment. Writes to `accessAttempts` and creates `lockerSessions` on success.
- `openLocker` (HTTPS) — called by mobile app; creates a `lockerOpenRequests` doc (status `pending`). MCU polls `lockerOpenRequests` via Firestore REST and executes pending requests.
- `completeLockerRequest` (HTTPS) — MCU calls this after a successful open to mark the request completed (triggers member notification).
- Firestore collections used: `members`, `lockers`, `lockerOpenRequests`, `accessAttempts`, `lockerSessions`.

Refer to `fitgate-firebase-functions/functions/index.js` for full logic and notification flows.

---

## 3️⃣ Developer Quick Start

Prerequisites:
- Arduino IDE or PlatformIO (ESP8266 toolchain)
- Firebase CLI, Node.js
- Flutter SDK (for mobile apps)

1) Clone the repo

```bash
git clone <repo-url>
cd FitGate
```

2) Cloud Functions

```bash
cd fitgate-firebase-functions/functions
npm install
firebase deploy --only functions,firestore:indexes
```

3) Configure and upload MCU firmware

- Open `fitgate-mcu/FitGate/FitGate.ino` and set your WiFi and the constants at the top:

```cpp
const char* ssid = "YourSSID";
const char* password = "YourPassword";
const char* firebaseUrlVerify = "https://<region>-<project>.cloudfunctions.net/verifyLockerAccess";
const char* firebaseUrlComplete = "https://<region>-<project>.cloudfunctions.net/completeLockerRequest";
const char* firestoreListUrl = "https://firestore.googleapis.com/v1/projects/<project>/databases/(default)/documents/lockerOpenRequests?pageSize=5&orderBy=requestedAt%20desc";
const char* LOCKER_ID = "<locker-id>";
```

- Make sure `client.setInsecure()` or valid TLS is configured for your environment.
- Upload to ESP8266.

4) Run Flutter apps (optional)

```bash
cd apps/fitgate_client
flutter pub get
flutter run

cd ../fitgate_admin
flutter pub get
flutter run
```

---

## 4️⃣ Typical flows & testing

- RFID flow: present a registered card → MCU calls `verifyLockerAccess` → on success stepper opens, `lockerSessions` created, and `accessAttempts` logged.
- App-initiated open: app calls `openLocker` → `lockerOpenRequests` doc created → MCU polls and executes → MCU calls `completeLockerRequest`.
- Debug: check MCU serial output (9600 baud) and Cloud Functions logs.

---

## 5️⃣ Troubleshooting (common)

- MCU Wi‑Fi fails: check SSID/password and Wi‑Fi retry timing in `FitGate.ino`.
- RFID not read: confirm wiring (RC522 SS to D2), 3.3V supply and SPI pins; check `uidToHexUpper` logs on serial.
- Stepper power issues: use a separate 5V supply for ULN2003/motor, common ground with ESP.
- Firestore polling: ensure `firestoreListUrl` points to your project and that functions are deployed.

---

If you want, I can:
- Add a schematic diagram and wiring photos for the ESP8266 + RC522 + ULN2003.
- Add sample cURL/Postman requests for `verifyLockerAccess` and `openLocker`.
- Merge this Entrio-style README into a top-level `README.md` branch-ready commit.
