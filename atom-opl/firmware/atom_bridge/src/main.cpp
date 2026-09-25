#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <Adafruit_NeoPixel.h>

static const uint32_t SERIAL_BAUD = 115200;
static const uint32_t MAGIC = 0x4B4E4C41; // "ALNK" little-endian
static const uint8_t LED_PIN = 27;

Adafruit_NeoPixel statusLed(1, LED_PIN, NEO_GRB + NEO_KHZ800);

static void setLed(uint8_t r, uint8_t g, uint8_t b) {
  statusLed.setPixelColor(0, statusLed.Color(r, g, b));
  statusLed.show();
}

enum MsgType : uint8_t {
  MSG_HELLO = 0x01,
  MSG_HELLO_ACK = 0x02,
  MSG_STATUS = 0x03,
  MSG_NET_FRAME = 0x10,
  MSG_NET_FRAME_ACK = 0x11,
  MSG_PING = 0x20,
  MSG_PONG = 0x21,
  MSG_ERROR = 0x7F
};

struct __attribute__((packed)) Header {
  uint32_t magic;
  uint8_t version;
  uint8_t type;
  uint16_t length;
  uint16_t sequence;
  uint16_t flags;
};

Preferences prefs;
WebServer server(80);

static bool setupMode = false;
static bool sawSerialBytes = false;
static bool linkValidated = false;
static uint16_t txSeq = 1;
static uint8_t rxPayload[1600];

static uint32_t crc32_update(uint32_t crc, const uint8_t *data, size_t len) {
  crc = ~crc;
  while (len--) {
    crc ^= *data++;
    for (int i = 0; i < 8; ++i)
      crc = (crc >> 1) ^ (0xEDB88320UL & (-(int32_t)(crc & 1)));
  }
  return ~crc;
}

static void sendFrame(uint8_t type, const uint8_t *payload, uint16_t len, uint16_t sequence = 0) {
  Header h;
  h.magic = MAGIC;
  h.version = 1;
  h.type = type;
  h.length = len;
  h.sequence = sequence ? sequence : txSeq++;
  h.flags = 0;

  uint32_t crc = 0;
  crc = crc32_update(crc, reinterpret_cast<uint8_t *>(&h), sizeof(h));
  if (payload && len) crc = crc32_update(crc, payload, len);

  Serial.write(reinterpret_cast<uint8_t *>(&h), sizeof(h));
  if (payload && len) Serial.write(payload, len);
  Serial.write(reinterpret_cast<uint8_t *>(&crc), sizeof(crc));
  Serial.flush();
}

static void sendText(uint8_t type, const String &s, uint16_t seq = 0) {
  sendFrame(type, reinterpret_cast<const uint8_t *>(s.c_str()), (uint16_t)s.length(), seq);
}

static String statusJson() {
  String s = "{";
  s += "\"fw\":\"ATOM-LINK-0.1\",";
  s += "\"wifi\":";
  s += (WiFi.status() == WL_CONNECTED ? "true" : "false");
  s += ",\"ip\":\"";
  s += WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : String("0.0.0.0");
  s += "\",\"rssi\":";
  s += String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0);
  s += "}";
  return s;
}

static bool readExact(uint8_t *dst, size_t len, uint32_t timeoutMs) {
  uint32_t start = millis();
  size_t got = 0;
  while (got < len && millis() - start < timeoutMs) {
    int avail = Serial.available();
    if (avail > 0) {
      int n = Serial.readBytes(dst + got, len - got);
      if (n > 0) got += n;
    } else {
      delay(1);
    }
  }
  return got == len;
}

static void handleFrame() {
  if (Serial.available() > 0 && !linkValidated) {
    sawSerialBytes = true;
    setLed(35, 0, 35); // purple = USB/UART bytes reached ESP32
  }

  if (Serial.available() < (int)sizeof(Header)) return;

  static uint8_t headerBytes[sizeof(Header)];
  if (!readExact(headerBytes, sizeof(Header), 100)) return;

  Header h;
  memcpy(&h, headerBytes, sizeof(h));

  if (h.magic != MAGIC || h.version != 1 || h.length > sizeof(rxPayload)) {
    // Any bytes already prove USB/UART activity. Purple stays latched.
    return;
  }

  if (h.length && !readExact(rxPayload, h.length, 250)) {
    sendText(MSG_ERROR, "short_payload", h.sequence);
    return;
  }

  uint32_t rxCrc = 0;
  if (!readExact(reinterpret_cast<uint8_t *>(&rxCrc), sizeof(rxCrc), 100)) {
    sendText(MSG_ERROR, "no_crc", h.sequence);
    return;
  }

  uint32_t crc = 0;
  crc = crc32_update(crc, reinterpret_cast<uint8_t *>(&h), sizeof(h));
  if (h.length) crc = crc32_update(crc, rxPayload, h.length);

  if (crc != rxCrc) {
    sendText(MSG_ERROR, "bad_crc", h.sequence);
    return;
  }

  switch (h.type) {
    case MSG_HELLO:
      linkValidated = true;
      setLed(0, 40, 0);
      sendText(MSG_HELLO_ACK, statusJson(), h.sequence);
      break;
    case MSG_PING:
      linkValidated = true;
      setLed(0, 40, 0); // green = valid ATOMLINK frame
      sendFrame(MSG_PONG, rxPayload, h.length, h.sequence);
      break;
    case MSG_STATUS:
      sendText(MSG_STATUS, statusJson(), h.sequence);
      break;
    case MSG_NET_FRAME:
      // The physical tunnel is ready, but full IP/NAT forwarding is deliberately
      // gated until the PS2-side virtual NIC is verified on real hardware.
      sendText(MSG_ERROR, "net_not_enabled_yet", h.sequence);
      break;
    default:
      sendText(MSG_ERROR, "unknown_type", h.sequence);
      break;
  }
}

static String pageHtml() {
  return String(
    "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>ATOM LINK</title></head><body style='font-family:sans-serif;background:#10141a;color:#fff;padding:24px'>"
    "<h2>ATOM LINK Wi-Fi</h2><form method='POST' action='/save'>"
    "<label>SSID</label><br><input name='ssid' style='width:100%;padding:10px'><br><br>"
    "<label>Senha</label><br><input name='pass' type='password' style='width:100%;padding:10px'><br><br>"
    "<button style='padding:12px;width:100%'>Salvar e reiniciar</button></form></body></html>");
}

static void startSetupPortal() {
  setupMode = true;
  setLed(35, 20, 0);
  WiFi.mode(WIFI_AP);
  WiFi.softAP("ATOM-LINK-SETUP");

  server.on("/", HTTP_GET, []() {
    server.send(200, "text/html", pageHtml());
  });

  server.on("/save", HTTP_POST, []() {
    String ssid = server.arg("ssid");
    String pass = server.arg("pass");
    if (ssid.length() == 0) {
      server.send(400, "text/plain", "SSID vazio");
      return;
    }
    prefs.begin("atomlink", false);
    prefs.putString("ssid", ssid);
    prefs.putString("pass", pass);
    prefs.end();
    server.send(200, "text/plain", "Salvo. Reiniciando...");
    delay(700);
    ESP.restart();
  });

  server.begin();
}

static bool connectStoredWifi() {
  prefs.begin("atomlink", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  prefs.end();

  if (ssid.length() == 0) return false;

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(250);
  }

  return WiFi.status() == WL_CONNECTED;
}

void setup() {
  statusLed.begin();
  statusLed.setBrightness(40);
  setLed(35, 0, 0);

  Serial.begin(SERIAL_BAUD);
  delay(250);

  bool ok = connectStoredWifi();
  if (!ok) {
    startSetupPortal();
  } else {
    setLed(0, 0, 35); // blue = Wi-Fi OK, no PS2 bytes yet
  }

  sendText(MSG_STATUS, statusJson());
}

void loop() {
  if (setupMode) server.handleClient();
  handleFrame();
  delay(1);
}
