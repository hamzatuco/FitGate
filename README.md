# FitGate — IoT Locker & Access Control System

**FitGate** je pametni IoT sistem za kontrolu pristupa i upravljanje ormarićima u teretanama i fitness centrima. Sistem omogućava identifikaciju članova putem RFID kartica, validaciju članarine, upravljanje ormarićima u realnom vremenu te centralizovanu administraciju korisnika i ormarića putem mobilne i web aplikacije.

FitGate kombinuje **ESP8266 mikrokontroler**, **Firebase backend** i **Flutter aplikacije** kako bi obezbijedio sigurno, pouzdano i skalabilno rješenje za upravljanje pristupom.

---

## Arhitektura sistema

Sistem se sastoji od sljedećih komponenti:

- **ESP8266 MCU firmware**  
  Upravljanje RFID čitačem, stepper motorom (brava ormarića), statusnom LED diodom i buzzerom, kao i periodična komunikacija s backendom.

- **Firebase Cloud Functions**  
  Poslovna logika sistema (verifikacija pristupa, otvaranje ormarića, završetak zahtjeva, notifikacije).

- **Flutter aplikacije**
  - `apps/fitgate_client` – aplikacija za članove teretane  
  - `apps/fitgate_admin` – aplikacija za osoblje teretane (administracija)

- **Zajednički modeli**
  - `shared/fitgate_shared` – zajednički Dart modeli i util klase

---

## Pin mapping (ESP8266 – autoritativni raspored)

### RC522 RFID (SPI)

| ESP8266 | GPIO | RC522 pin | Opis |
|------|------|----------|------|
| D2 | GPIO4 | SDA / SS | Chip Select |
| – | – | RST | Spojen direktno na 3.3V |
| 3V3 | – | VCC | Napajanje (isključivo 3.3V) |
| GND | – | GND | Masa |

---

### LED i buzzer

| Komponenta | ESP8266 pin | Opis |
|---------|------------|------|
| STATUS_LED | D1 (GPIO5) | Statusna LED (active-low konfiguracija) |
| BUZZER | D1 (GPIO5) | Zvučna signalizacija |

---

### Stepper motor (28BYJ-48 + ULN2003)

| ULN2003 | ESP8266 pin | GPIO |
|-------|-------------|------|
| IN1 | D3 | GPIO0 |
| IN2 | D4 | GPIO2 |
| IN3 | D8 | GPIO15 |
| IN4 | RX | GPIO3 |

**Napomena:**  
- Motor se napaja sa **5V** (USB/VIN)  
- **Zajednička masa (GND)** između ESP8266 i ULN2003 je obavezna

---

## Backend i Cloud endpoints

### Glavni endpointi

- **`verifyLockerAccess`**  
  Poziva ga ESP8266 prilikom skeniranja RFID kartice.  
  Provjerava validnost kartice, status članarine i dodijeljeni ormarić.

- **`openLocker`**  
  Poziva ga Flutter aplikacija (član).  
  Kreira zahtjev za otvaranje ormarića (`lockerOpenRequests`).

- **`completeLockerRequest`**  
  Poziva ga ESP8266 nakon uspješnog otvaranja ormarića.

---

### Firestore kolekcije

- `members`
- `lockers`
- `lockerOpenRequests`
- `accessAttempts`
- `lockerSessions`

---

## Tipični tokovi rada

### RFID pristup
1. Član prisloni RFID karticu  
2. ESP8266 šalje UID kartice backendu  
3. Backend validira pristup  
4. Ormarić se otvara ili se pristup odbija  
5. Događaj se evidentira u bazi podataka

### Otvaranje preko aplikacije
1. Član pošalje zahtjev iz aplikacije  
2. Backend kreira `lockerOpenRequests` zapis  
3. ESP8266 periodično vrši polling  
4. Ormarić se otvara i zahtjev se označava kao završen

---

## Pokretanje projekta (Developer Quick Start)

### Preduvjeti
- Arduino IDE (ESP8266 toolchain)
- Firebase CLI + Node.js
- Flutter SDK

### Firmware (ESP8266)

U fajlu `fitgate-mcu/FitGate/FitGate.ino` podesiti:

```cpp
const char* ssid = "YourSSID";
const char* password = "YourPassword";
const char* LOCKER_ID = "<locker-id>";
