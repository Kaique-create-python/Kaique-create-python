#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <Adafruit_NeoPixel.h>

extern "C" {
#include "esp_err.h"
#include "esp_netif.h"
#include "esp_netif_defaults.h"
#include "esp_netif_types.h"
#include "lwip/inet.h"
#include "dhcpserver/dhcpserver.h"
#include "dhcpserver/dhcpserver_options.h"
}

#if !defined(CONFIG_LWIP_IPV4_NAPT) || !CONFIG_LWIP_IPV4_NAPT
#error "ATOM Link requires CONFIG_LWIP_IPV4_NAPT"
#endif
#if !defined(CONFIG_LWIP_IP_FORWARD) || !CONFIG_LWIP_IP_FORWARD
#error "ATOM Link requires CONFIG_LWIP_IP_FORWARD"
#endif

static const uint32_t SERIAL_BAUD = 115200;
static const uint32_t MAGIC = 0x4B4E4C41; // "ALNK" little-endian
static const uint8_t LED_PIN = 27;
static const uint16_t MAX_PAYLOAD = 1600;

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
static bool linkValidated = false;
static bool networkTrafficSeen = false;
static uint16_t txSeq = 1;

static uint8_t serialRx[4096];
static size_t serialRxLen = 0;
static uint8_t rxPayload[MAX_PAYLOAD];

static SemaphoreHandle_t serialTxMutex = nullptr;

/* -------------------- PS2 virtual Ethernet / NAPT -------------------- */

typedef struct {
  esp_netif_driver_base_t base;
} atom_netif_glue_t;

static atom_netif_glue_t ps2Glue = {};
static esp_netif_t *ps2Netif = nullptr;
static esp_netif_t *staNetif = nullptr;
static bool ps2NetifUp = false;
static bool ps2DhcpRunning = false;
static bool forwardingReady = false;

static const esp_netif_ip_info_t ps2IpInfo = {
  .ip = { .addr = ESP_IP4TOADDR(10, 42, 0, 1) },
  .netmask = { .addr = ESP_IP4TOADDR(255, 255, 255, 0) },
  .gw = { .addr = ESP_IP4TOADDR(10, 42, 0, 1) },
};

static uint8_t ps2GatewayMac[6] = {0x02, 0x4B, 0x4E, 0x4C, 0x00, 0x01};

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
  if (len > MAX_PAYLOAD) return;

  Header h;
  h.magic = MAGIC;
  h.version = 1;
  h.type = type;
  h.length = len;
  h.sequence = sequence ? sequence : txSeq++;
  h.flags = 0;

  uint32_t crc = 0;
  crc = crc32_update(crc, reinterpret_cast<const uint8_t *>(&h), sizeof(h));
  if (payload && len) crc = crc32_update(crc, payload, len);

  if (serialTxMutex) xSemaphoreTake(serialTxMutex, portMAX_DELAY);
  Serial.write(reinterpret_cast<const uint8_t *>(&h), sizeof(h));
  if (payload && len) Serial.write(payload, len);
  Serial.write(reinterpret_cast<const uint8_t *>(&crc), sizeof(crc));
  Serial.flush();
  if (serialTxMutex) xSemaphoreGive(serialTxMutex);
}

static void sendText(uint8_t type, const String &s, uint16_t seq = 0) {
  sendFrame(type, reinterpret_cast<const uint8_t *>(s.c_str()), (uint16_t)s.length(), seq);
}

static esp_err_t ps2_netif_transmit(void *handle, void *buffer, size_t len) {
  (void)handle;

  if (!linkValidated || buffer == nullptr || len < 14 || len > 1518) {
    return ESP_ERR_INVALID_STATE;
  }

  sendFrame(MSG_NET_FRAME, reinterpret_cast<const uint8_t *>(buffer), (uint16_t)len);

  if (!networkTrafficSeen) {
    networkTrafficSeen = true;
    setLed(0, 28, 35); // cyan = Ethernet traffic is flowing
  }

  return ESP_OK;
}

static void ps2_netif_free_rx(void *handle, void *buffer) {
  (void)handle;
  free(buffer);
}

static esp_err_t ps2_post_attach(esp_netif_t *esp_netif, void *args) {
  atom_netif_glue_t *glue = reinterpret_cast<atom_netif_glue_t *>(args);
  glue->base.netif = esp_netif;

  esp_netif_driver_ifconfig_t driver_cfg = {};
  driver_cfg.handle = glue;
  driver_cfg.transmit = ps2_netif_transmit;
  driver_cfg.driver_free_rx_buffer = ps2_netif_free_rx;

  esp_err_t err = esp_netif_set_driver_config(esp_netif, &driver_cfg);
  if (err != ESP_OK) return err;

  return esp_netif_set_mac(esp_netif, ps2GatewayMac);
}

static void setupForwarding() {
  if (!ps2Netif || forwardingReady) return;

  esp_netif_dns_info_t dns = {};
  if (!staNetif ||
      esp_netif_get_dns_info(staNetif, ESP_NETIF_DNS_MAIN, &dns) != ESP_OK ||
      dns.ip.u_addr.ip4.addr == 0) {
    dns.ip.u_addr.ip4.addr = ESP_IP4TOADDR(8, 8, 8, 8);
    dns.ip.type = IPADDR_TYPE_V4;
  }

  dhcps_offer_t dnsOffer = OFFER_DNS;
  esp_netif_dhcps_option(ps2Netif, ESP_NETIF_OP_SET,
                         ESP_NETIF_DOMAIN_NAME_SERVER,
                         &dnsOffer, sizeof(dnsOffer));
  esp_netif_set_dns_info(ps2Netif, ESP_NETIF_DNS_MAIN, &dns);

  esp_err_t natResult = esp_netif_napt_enable(ps2Netif);
  if (natResult == ESP_OK) {
    forwardingReady = true;
  }
}

static bool initPs2Netif() {
  if (ps2Netif) return true;

  ps2Glue.base.post_attach = ps2_post_attach;

  esp_netif_inherent_config_t base_cfg = ESP_NETIF_INHERENT_DEFAULT_ETH();
  base_cfg.if_key = "ATOM_PS2";
  base_cfg.if_desc = "ATOM PS2 virtual Ethernet";
  base_cfg.route_prio = 10;
  base_cfg.flags = ESP_NETIF_DHCP_SERVER;
  base_cfg.ip_info = &ps2IpInfo;

  esp_netif_config_t cfg = {};
  cfg.base = &base_cfg;
  cfg.stack = ESP_NETIF_NETSTACK_DEFAULT_ETH;

  ps2Netif = esp_netif_new(&cfg);
  if (!ps2Netif) return false;

  if (esp_netif_attach(ps2Netif, &ps2Glue) != ESP_OK) {
    esp_netif_destroy(ps2Netif);
    ps2Netif = nullptr;
    return false;
  }

  return true;
}

static void bringPs2NetifUp() {
  if (!ps2Netif && !initPs2Netif()) return;

  if (!ps2NetifUp) {
    esp_netif_action_start(ps2Netif, nullptr, 0, nullptr);
    esp_netif_action_connected(ps2Netif, nullptr, 0, nullptr);
    ps2NetifUp = true;
  }

  setupForwarding();

  if (!ps2DhcpRunning) {
    esp_err_t err = esp_netif_dhcps_start(ps2Netif);
    if (err == ESP_OK || err == ESP_ERR_ESP_NETIF_DHCP_ALREADY_STARTED) {
      ps2DhcpRunning = true;
    }
  }
}

static void injectPs2Ethernet(const uint8_t *frame, uint16_t len) {
  if (!ps2Netif || !frame || len < 14 || len > 1518) return;

  uint8_t *copy = reinterpret_cast<uint8_t *>(malloc(len));
  if (!copy) return;

  memcpy(copy, frame, len);

  if (esp_netif_receive(ps2Netif, copy, len, nullptr) != ESP_OK) {
    // esp_netif normally frees via ps2_netif_free_rx on failure/success.
    // Do not free here to avoid a double free across IDF versions.
  }

  if (!networkTrafficSeen) {
    networkTrafficSeen = true;
    setLed(0, 28, 35);
  }
}

/* -------------------------- ATOMLINK parser -------------------------- */

static String statusJson() {
  String s = "{";
  s += "\"fw\":\"ATOM-LINK-0.6-NAPT\",";
  s += "\"wifi\":";
  s += (WiFi.status() == WL_CONNECTED ? "true" : "false");
  s += ",\"ip\":\"";
  s += WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : String("0.0.0.0");
  s += "\",\"rssi\":";
  s += String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0);
  s += ",\"ps2_link\":";
  s += linkValidated ? "true" : "false";
  s += ",\"napt\":";
  s += forwardingReady ? "true" : "false";
  s += "}";
  return s;
}

static void dropRxPrefix(size_t count) {
  if (count >= serialRxLen) {
    serialRxLen = 0;
    return;
  }
  memmove(serialRx, serialRx + count, serialRxLen - count);
  serialRxLen -= count;
}

static int findMagic() {
  const uint8_t magicBytes[4] = {0x41, 0x4C, 0x4E, 0x4B};

  if (serialRxLen < 4) return -1;

  for (size_t i = 0; i + 4 <= serialRxLen; ++i) {
    if (serialRx[i] == magicBytes[0] &&
        serialRx[i + 1] == magicBytes[1] &&
        serialRx[i + 2] == magicBytes[2] &&
        serialRx[i + 3] == magicBytes[3]) {
      return (int)i;
    }
  }

  return -1;
}

static void processFrame(const Header &h, const uint8_t *payload) {
  switch (h.type) {
    case MSG_HELLO:
      linkValidated = true;
      if (!networkTrafficSeen) setLed(0, 40, 0);
      bringPs2NetifUp();
      sendText(MSG_HELLO_ACK, statusJson(), h.sequence);
      break;

    case MSG_PING:
      linkValidated = true;
      if (!networkTrafficSeen) setLed(0, 40, 0);
      bringPs2NetifUp();
      sendFrame(MSG_PONG, payload, h.length, h.sequence);
      break;

    case MSG_STATUS:
      sendText(MSG_STATUS, statusJson(), h.sequence);
      break;

    case MSG_NET_FRAME:
      if (!linkValidated) {
        linkValidated = true;
        bringPs2NetifUp();
      }
      injectPs2Ethernet(payload, h.length);
      break;

    default:
      sendText(MSG_ERROR, "unknown_type", h.sequence);
      break;
  }
}

static void parseRxFrames() {
  while (serialRxLen >= 4) {
    int pos = findMagic();

    if (pos < 0) {
      if (serialRxLen > 3) dropRxPrefix(serialRxLen - 3);
      return;
    }

    if (pos > 0) dropRxPrefix((size_t)pos);
    if (serialRxLen < sizeof(Header)) return;

    Header h;
    memcpy(&h, serialRx, sizeof(h));

    if (h.magic != MAGIC || h.version != 1 || h.length > MAX_PAYLOAD) {
      dropRxPrefix(1);
      continue;
    }

    size_t total = sizeof(Header) + (size_t)h.length + sizeof(uint32_t);
    if (serialRxLen < total) return;

    uint32_t rxCrc = 0;
    memcpy(&rxCrc, serialRx + sizeof(Header) + h.length, sizeof(rxCrc));

    uint32_t crc = 0;
    crc = crc32_update(crc, serialRx, sizeof(Header));
    if (h.length) crc = crc32_update(crc, serialRx + sizeof(Header), h.length);

    if (crc != rxCrc) {
      dropRxPrefix(1);
      continue;
    }

    if (h.length) memcpy(rxPayload, serialRx + sizeof(Header), h.length);
    processFrame(h, h.length ? rxPayload : nullptr);
    dropRxPrefix(total);
  }
}

static void handleSerial() {
  while (Serial.available() > 0) {
    int v = Serial.read();
    if (v < 0) break;

    if (serialRxLen < sizeof(serialRx)) {
      serialRx[serialRxLen++] = (uint8_t)v;
    } else {
      memmove(serialRx, serialRx + 1, sizeof(serialRx) - 1);
      serialRx[sizeof(serialRx) - 1] = (uint8_t)v;
    }
  }

  parseRxFrames();
}

/* --------------------------- Wi-Fi portal ---------------------------- */

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
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(250);
  }

  return WiFi.status() == WL_CONNECTED;
}

void setup() {
  statusLed.begin();
  statusLed.setBrightness(40);
  setLed(35, 0, 0);

  serialTxMutex = xSemaphoreCreateMutex();

  Serial.setRxBufferSize(8192);
  Serial.setTxBufferSize(4096);
  Serial.begin(SERIAL_BAUD);
  delay(250);

  bool ok = connectStoredWifi();

  if (!ok) {
    startSetupPortal();
  } else {
    staNetif = esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
    if (staNetif) esp_netif_set_default_netif(staNetif);

    initPs2Netif();
    setLed(0, 0, 35);
  }

  sendText(MSG_STATUS, statusJson());
}

void loop() {
  if (setupMode) {
    server.handleClient();
  } else {
    handleSerial();

    // Recover if the hotspot temporarily drops.
    if (WiFi.status() != WL_CONNECTED) {
      setLed(35, 0, 0);
    } else if (!linkValidated && !networkTrafficSeen) {
      setLed(0, 0, 35);
    }
  }

  delay(1);
}
