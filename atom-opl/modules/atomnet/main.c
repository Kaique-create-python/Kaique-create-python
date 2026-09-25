#include <types.h>
#include <loadcore.h>
#include <stdio.h>
#include <sysclib.h>
#include <thbase.h>
#include <usbd.h>
#include <usbd_macro.h>
#include <irx.h>

IRX_ID("atomnet", 1, 4);

#define VID_FTDI 0x0403

#define SERIAL_KIND_UNKNOWN 0
#define SERIAL_KIND_FTDI    1

#define FTDI_REQ_RESET       0
#define FTDI_REQ_SET_BAUD    3
#define FTDI_REQ_SET_DATA    4
#define FTDI_REQ_SET_LATENCY 9
#define FTDI_REQTYPE (USB_DIR_OUT | USB_TYPE_VENDOR | USB_RECIP_DEVICE)
#define FTDI_IFACE_A 1

#define ATOM_MAGIC 0x4B4E4C41u
#define MSG_PING   0x20
#define MSG_PONG   0x21

typedef struct __attribute__((packed)) {
    u32 magic;
    u8 version;
    u8 type;
    u16 length;
    u16 sequence;
    u16 flags;
} atom_header_t;

typedef struct {
    int dev_id;
    int control;
    int bulk_in;
    int bulk_out;
    u16 vid;
    u16 pid;
    int serial_kind;
} atom_usb_t;

static atom_usb_t g_atom = {-1, -1, -1, -1, 0, 0, SERIAL_KIND_UNKNOWN};

static volatile int g_xfer_done = 0;
static volatile int g_xfer_result = 0;
static volatile int g_xfer_count = 0;
static volatile int g_device_ready = 0;

static u8 g_tx[64] __attribute__((aligned(64)));
static u8 g_rx[64] __attribute__((aligned(64)));

static u16 g_sequence = 1;
static int g_heartbeat_thread = -1;

static int atom_probe(int devId);
static int atom_connect(int devId);
static int atom_disconnect(int devId);

static int open_ftdi_endpoints(int devId, UsbConfigDescriptor *config)
{
    u8 *p;
    u8 *end;
    UsbInterfaceDescriptor *interface = NULL;
    UsbEndpointDescriptor *ep;

    if (config == NULL)
        return -1;

    p = (u8 *)config + config->bLength;
    end = (u8 *)config + config->wTotalLength;

    while (p + 2 <= end) {
        u8 len = p[0];
        u8 type = p[1];

        if (len < 2 || p + len > end)
            break;

        if (type == USB_DT_INTERFACE) {
            interface = (UsbInterfaceDescriptor *)p;
            printf("ATOMNET: iface=%d alt=%d eps=%d cls=%02X sub=%02X proto=%02X\n",
                   interface->bInterfaceNumber,
                   interface->bAlternateSetting,
                   interface->bNumEndpoints,
                   interface->bInterfaceClass,
                   interface->bInterfaceSubClass,
                   interface->bInterfaceProtocol);
        } else if (type == USB_DT_ENDPOINT && interface != NULL) {
            ep = (UsbEndpointDescriptor *)p;

            if ((ep->bmAttributes & USB_ENDPOINT_XFERTYPE_MASK) ==
                USB_ENDPOINT_XFER_BULK) {
                if ((ep->bEndpointAddress & USB_ENDPOINT_DIR_MASK) == USB_DIR_IN) {
                    if (g_atom.bulk_in < 0) {
                        g_atom.bulk_in = UsbOpenEndpointAligned(devId, ep);
                        printf("ATOMNET: bulk IN ep=%02X pipe=%d mps=%d\n",
                               ep->bEndpointAddress, g_atom.bulk_in, ep->wMaxPacketSize);
                    }
                } else {
                    if (g_atom.bulk_out < 0) {
                        g_atom.bulk_out = UsbOpenEndpointAligned(devId, ep);
                        printf("ATOMNET: bulk OUT ep=%02X pipe=%d mps=%d\n",
                               ep->bEndpointAddress, g_atom.bulk_out, ep->wMaxPacketSize);
                    }
                }
            }
        }

        p += len;
    }

    return (g_atom.bulk_in >= 0 && g_atom.bulk_out >= 0) ? 0 : -1;
}

static UsbDriver atom_usb_driver = {
    NULL, NULL, "atomnet-usb", atom_probe, atom_connect, atom_disconnect
};

static void xfer_cb(int result, int count, void *arg)
{
    (void)arg;
    g_xfer_result = result;
    g_xfer_count = count;
    g_xfer_done = 1;
}

static int wait_xfer(int start_result, int timeout_ms)
{
    int elapsed = 0;

    if (start_result < 0)
        return start_result;

    while (!g_xfer_done && elapsed < timeout_ms) {
        DelayThread(1000);
        elapsed++;
    }

    if (!g_xfer_done)
        return -1000;

    if (g_xfer_result != USB_RC_OK)
        return -g_xfer_result;

    return g_xfer_count;
}

static int control_out(int request, int value, int index)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbControlTransfer(
        g_atom.control,
        FTDI_REQTYPE,
        request,
        value,
        index,
        0,
        NULL,
        xfer_cb,
        NULL);

    return wait_xfer(result, 500);
}

static int set_configuration(int value)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbSetDeviceConfiguration(
        g_atom.control,
        value,
        xfer_cb,
        NULL);

    return wait_xfer(result, 800);
}

static int bulk_out(const void *data, int len)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbBulkTransfer(
        g_atom.bulk_out,
        (void *)data,
        len,
        xfer_cb,
        NULL);

    return wait_xfer(result, 700);
}

static int bulk_in(void *data, int len, int timeout_ms)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbBulkTransfer(
        g_atom.bulk_in,
        data,
        len,
        xfer_cb,
        NULL);

    return wait_xfer(result, timeout_ms);
}

static u32 crc32_update(u32 crc, const u8 *data, int len)
{
    int i;

    crc = ~crc;

    while (len-- > 0) {
        crc ^= *data++;
        for (i = 0; i < 8; i++)
            crc = (crc >> 1) ^ (0xEDB88320u & (-(s32)(crc & 1)));
    }

    return ~crc;
}

static int configure_ftdi(void)
{
    int result;

    /*
     * FTDI interface A uses wIndex=1.
     * v0.2 used 0 here, which can leave the UART unconfigured on FT23x parts.
     */
    result = control_out(FTDI_REQ_RESET, 0, FTDI_IFACE_A);
    if (result < 0)
        return result;

    /* 3 MHz / 26 ~= 115200 baud on classic FTDI divisors. */
    result = control_out(FTDI_REQ_SET_BAUD, 26, FTDI_IFACE_A);
    if (result < 0)
        return result;

    /* 8N1. */
    result = control_out(FTDI_REQ_SET_DATA, 8, FTDI_IFACE_A);
    if (result < 0)
        return result;

    result = control_out(FTDI_REQ_SET_LATENCY, 1, FTDI_IFACE_A);
    if (result < 0)
        return result;

    return 0;
}

static int find_pong(const u8 *buf, int len, u16 sequence)
{
    int i;

    /*
     * FTDI bulk-IN adds two modem-status bytes to USB packets, and there may
     * also be stale boot/status bytes in its RX FIFO. Scan instead of assuming
     * the response begins at a fixed offset.
     */
    for (i = 0; i + (int)sizeof(atom_header_t) + 4 <= len; i++) {
        const atom_header_t *h = (const atom_header_t *)&buf[i];

        if (h->magic == ATOM_MAGIC &&
            h->version == 1 &&
            h->type == MSG_PONG &&
            h->sequence == sequence &&
            h->length == 0) {
            return 0;
        }
    }

    return -1;
}

static int atom_ping(void)
{
    atom_header_t *h = (atom_header_t *)g_tx;
    u32 crc;
    int tx_len;
    int rx_len;
    int tries;
    u16 sequence;

    if (!g_device_ready || g_atom.bulk_in < 0 || g_atom.bulk_out < 0)
        return -10;

    memset(g_tx, 0, sizeof(g_tx));
    sequence = g_sequence++;

    h->magic = ATOM_MAGIC;
    h->version = 1;
    h->type = MSG_PING;
    h->length = 0;
    h->sequence = sequence;
    h->flags = 0;

    crc = crc32_update(0, (u8 *)h, sizeof(*h));
    *(u32 *)(g_tx + sizeof(*h)) = crc;
    tx_len = sizeof(*h) + sizeof(u32);

    if (bulk_out(g_tx, tx_len) < 0)
        return -1;

    /*
     * Read several packets because the first one can contain old UART bytes
     * that were queued before the PS2 claimed the FTDI interface.
     */
    for (tries = 0; tries < 4; tries++) {
        memset(g_rx, 0, sizeof(g_rx));
        rx_len = bulk_in(g_rx, sizeof(g_rx), 350);

        if (rx_len > 0 && find_pong(g_rx, rx_len, sequence) == 0)
            return 0;

        DelayThread(20000);
    }

    return -2;
}

static void HeartbeatThread(void *arg)
{
    int result;
    int last_ok = 0;

    (void)arg;

    while (1) {
        if (g_device_ready) {
            result = atom_ping();

            if (result == 0) {
                if (!last_ok)
                    printf("ATOMNET: ATOM-LINK online, heartbeat OK\n");
                last_ok = 1;
            } else {
                if (last_ok)
                    printf("ATOMNET: heartbeat lost (%d)\n", result);
                last_ok = 0;
            }
        } else {
            last_ok = 0;
        }

        DelayThread(1000000);
    }
}

static int atom_probe(int devId)
{
    UsbDeviceDescriptor *device;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_DEVICE);

    if (device == NULL)
        return 0;

    /*
     * ATOM Echo documentation uses an FTDI USB serial bridge.
     * Accept the FTDI vendor instead of only two product IDs because M5Stack
     * has shipped multiple FT23x variants.
     */
    if (device->idVendor != VID_FTDI)
        return 0;

    printf("ATOMNET: FTDI candidate %04X:%04X dev=%d\n",
           device->idVendor, device->idProduct, devId);

    return 1;
}

static int atom_connect(int devId)
{
    UsbDeviceDescriptor *device;
    UsbConfigDescriptor *config;
    int result;

    if (g_atom.dev_id >= 0)
        return 1;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_DEVICE);
    if (device == NULL)
        return 1;

    config = (UsbConfigDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, device, USB_DT_CONFIG);
    if (config == NULL)
        return 1;

    g_atom.dev_id = devId;
    g_atom.vid = device->idVendor;
    g_atom.pid = device->idProduct;
    g_atom.serial_kind = SERIAL_KIND_FTDI;
    g_atom.control = UsbOpenEndpoint(devId, NULL);
    g_atom.bulk_in = -1;
    g_atom.bulk_out = -1;
    g_device_ready = 0;

    result = open_ftdi_endpoints(devId, config);
    if (result < 0)
        printf("ATOMNET: descriptor walk did not find both bulk endpoints\n");

    if (g_atom.control < 0 || g_atom.bulk_in < 0 || g_atom.bulk_out < 0) {
        printf("ATOMNET: endpoints missing ctl=%d in=%d out=%d\n",
               g_atom.control, g_atom.bulk_in, g_atom.bulk_out);
        atom_disconnect(devId);
        return 1;
    }

    result = set_configuration(config->bConfigurationValue);
    if (result < 0) {
        printf("ATOMNET: SET_CONFIGURATION failed %d\n", result);
        atom_disconnect(devId);
        return 1;
    }

    result = configure_ftdi();
    if (result < 0) {
        printf("ATOMNET: FTDI setup failed %d\n", result);
        atom_disconnect(devId);
        return 1;
    }

    g_device_ready = 1;

    printf("ATOMNET: FTDI configured %04X:%04X, heartbeat armed\n",
           g_atom.vid, g_atom.pid);

    return 0;
}

static int atom_disconnect(int devId)
{
    g_device_ready = 0;

    if (g_atom.dev_id != devId)
        return 0;

    if (g_atom.bulk_in >= 0)
        UsbCloseEndpoint(g_atom.bulk_in);
    if (g_atom.bulk_out >= 0)
        UsbCloseEndpoint(g_atom.bulk_out);
    if (g_atom.control >= 0)
        UsbCloseEndpoint(g_atom.control);

    g_atom.dev_id = -1;
    g_atom.control = -1;
    g_atom.bulk_in = -1;
    g_atom.bulk_out = -1;
    g_atom.vid = 0;
    g_atom.pid = 0;
    g_atom.serial_kind = SERIAL_KIND_UNKNOWN;

    printf("ATOMNET: FTDI disconnected\n");
    return 0;
}

int _start(int argc, char *argv[])
{
    int result;
    iop_thread_t thread;

    (void)argc;
    (void)argv;

    printf("ATOMNET v0.3 USBFix: starting\n");

    result = UsbRegisterDriver(&atom_usb_driver);
    if (result < 0) {
        printf("ATOMNET: UsbRegisterDriver failed %d\n", result);
        return MODULE_NO_RESIDENT_END;
    }

    thread.attr = TH_C;
    thread.option = 0;
    thread.thread = &HeartbeatThread;
    thread.priority = 0x2f;
    thread.stacksize = 0x1000;

    g_heartbeat_thread = CreateThread(&thread);
    if (g_heartbeat_thread > 0)
        StartThread(g_heartbeat_thread, NULL);
    else
        printf("ATOMNET: heartbeat thread create failed %d\n", g_heartbeat_thread);

    return MODULE_RESIDENT_END;
}
