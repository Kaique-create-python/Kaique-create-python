#include <types.h>
#include <loadcore.h>
#include <stdio.h>
#include <sysclib.h>
#include <thbase.h>
#include <usbd.h>
#include <usbd_macro.h>
#include <irx.h>

IRX_ID("atomnet", 1, 1);

#define VID_FTDI   0x0403
#define PID_FT232R 0x6001
#define PID_FT231X 0x6015

#define VID_SILABS 0x10C4
#define PID_CP210X 0xEA60
#define PID_CP2105 0xEA70

#define VID_WCH     0x1A86
#define PID_CH340   0x7523
#define PID_CH341   0x5523
#define PID_CH9102  0x55D4

#define SERIAL_KIND_UNKNOWN 0
#define SERIAL_KIND_FTDI    1
#define SERIAL_KIND_CP210X  2
#define SERIAL_KIND_WCH     3

#define FTDI_REQ_RESET       0
#define FTDI_REQ_SET_BAUD    3
#define FTDI_REQ_SET_DATA    4
#define FTDI_REQ_SET_LATENCY 9
#define FTDI_REQTYPE (USB_DIR_OUT | USB_TYPE_VENDOR | USB_RECIP_DEVICE)

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

static u8 g_tx[64] __attribute__((aligned(64)));
static u8 g_rx[64] __attribute__((aligned(64)));

static int atom_probe(int devId);
static int atom_connect(int devId);
static int atom_disconnect(int devId);

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

    return wait_xfer(result, 300);
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

    return wait_xfer(result, 500);
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

    return wait_xfer(result, 500);
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

static int serial_kind(u16 vid, u16 pid)
{
    if (vid == VID_FTDI && (pid == PID_FT232R || pid == PID_FT231X))
        return SERIAL_KIND_FTDI;

    if (vid == VID_SILABS && (pid == PID_CP210X || pid == PID_CP2105))
        return SERIAL_KIND_CP210X;

    if (vid == VID_WCH && (pid == PID_CH340 || pid == PID_CH341 || pid == PID_CH9102))
        return SERIAL_KIND_WCH;

    return SERIAL_KIND_UNKNOWN;
}

static int configure_ftdi(void)
{
    int result;

    /* Reset UART. */
    result = control_out(FTDI_REQ_RESET, 0, 0);
    if (result < 0)
        return result;

    /*
     * FT232R base clock is 3 MHz.
     * Divisor 26 gives about 115384 baud, close enough for 115200.
     */
    result = control_out(FTDI_REQ_SET_BAUD, 26, 0);
    if (result < 0)
        return result;

    /* 8 data bits, 1 stop bit, no parity. */
    result = control_out(FTDI_REQ_SET_DATA, 8, 0);
    if (result < 0)
        return result;

    /* Reduce receive latency for the PS2 <-> ATOM link. */
    result = control_out(FTDI_REQ_SET_LATENCY, 1, 0);
    if (result < 0)
        return result;

    return 0;
}

static int atom_ping(void)
{
    atom_header_t *h = (atom_header_t *)g_tx;
    atom_header_t *rh;
    u32 crc;
    int tx_len;
    int rx_len;
    int offset;

    memset(g_tx, 0, sizeof(g_tx));
    memset(g_rx, 0, sizeof(g_rx));

    h->magic = ATOM_MAGIC;
    h->version = 1;
    h->type = MSG_PING;
    h->length = 0;
    h->sequence = 1;
    h->flags = 0;

    crc = crc32_update(0, (u8 *)h, sizeof(*h));
    *(u32 *)(g_tx + sizeof(*h)) = crc;

    tx_len = sizeof(*h) + sizeof(u32);

    if (bulk_out(g_tx, tx_len) < 0)
        return -1;

    /*
     * FTDI bulk-IN packets begin with two modem-status bytes.
     * CP210x/WCH support will get their own setup/parser after hardware ID test.
     */
    rx_len = bulk_in(g_rx, sizeof(g_rx), 800);
    if (rx_len < 0)
        return -2;

    offset = (g_atom.serial_kind == SERIAL_KIND_FTDI) ? 2 : 0;

    if (rx_len < offset + (int)sizeof(atom_header_t) + 4)
        return -3;

    rh = (atom_header_t *)(g_rx + offset);

    if (rh->magic != ATOM_MAGIC || rh->version != 1 || rh->type != MSG_PONG)
        return -4;

    return 0;
}

static int atom_probe(int devId)
{
    UsbDeviceDescriptor *device;
    int kind;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_DEVICE);

    if (device == NULL)
        return 0;

    kind = serial_kind(device->idVendor, device->idProduct);
    if (kind == SERIAL_KIND_UNKNOWN)
        return 0;

    printf("ATOMNET: USB serial candidate %04X:%04X dev=%d kind=%d\n",
           device->idVendor, device->idProduct, devId, kind);

    return 1;
}

static int atom_connect(int devId)
{
    UsbDeviceDescriptor *device;
    UsbConfigDescriptor *config;
    UsbEndpointDescriptor *endpoint;
    int i;
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
    g_atom.serial_kind = serial_kind(g_atom.vid, g_atom.pid);
    g_atom.control = UsbOpenEndpoint(devId, NULL);
    g_atom.bulk_in = -1;
    g_atom.bulk_out = -1;

    endpoint = (UsbEndpointDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_ENDPOINT);

    for (i = 0; endpoint != NULL && i < 16; i++) {
        if ((endpoint->bmAttributes & USB_ENDPOINT_XFERTYPE_MASK) ==
            USB_ENDPOINT_XFER_BULK) {
            if ((endpoint->bEndpointAddress & USB_ENDPOINT_DIR_MASK) == USB_DIR_IN) {
                if (g_atom.bulk_in < 0)
                    g_atom.bulk_in = UsbOpenEndpointAligned(devId, endpoint);
            } else {
                if (g_atom.bulk_out < 0)
                    g_atom.bulk_out = UsbOpenEndpointAligned(devId, endpoint);
            }
        }

        if (endpoint->bLength == 0)
            break;

        endpoint = (UsbEndpointDescriptor *)((u8 *)endpoint + endpoint->bLength);
    }

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

    if (g_atom.serial_kind == SERIAL_KIND_FTDI) {
        result = configure_ftdi();
        if (result < 0) {
            printf("ATOMNET: FTDI setup failed %d\n", result);
            atom_disconnect(devId);
            return 1;
        }

        DelayThread(50000);

        result = atom_ping();
        if (result == 0)
            printf("ATOMNET: ATOM-LINK PONG received - bridge alive\n");
        else
            printf("ATOMNET: USB found, ATOM-LINK ping pending (%d)\n", result);
    } else {
        printf("ATOMNET: serial chip detected; setup driver kind=%d pending\n",
               g_atom.serial_kind);
    }

    return 0;
}

static int atom_disconnect(int devId)
{
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

    printf("ATOMNET: USB serial disconnected\n");
    return 0;
}

int _start(int argc, char *argv[])
{
    int result;

    (void)argc;
    (void)argv;

    printf("ATOMNET v0.2: starting USB-UART link detector\n");

    result = UsbRegisterDriver(&atom_usb_driver);
    if (result < 0) {
        printf("ATOMNET: UsbRegisterDriver failed %d\n", result);
        return MODULE_NO_RESIDENT_END;
    }

    return MODULE_RESIDENT_END;
}
