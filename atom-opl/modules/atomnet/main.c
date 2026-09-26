#include <types.h>
#include <loadcore.h>
#include <stdio.h>
#include <sysclib.h>
#include <thbase.h>
#include <thsemap.h>
#include <thevent.h>
#include <usbd.h>
#include <usbd_macro.h>
#include <irx.h>

IRX_ID("atomnet", 1, 6);

#define VID_FTDI 0x0403
#define PID_FT232R 0x6001
#define PID_FT231X 0x6015

#define FTDI_REQ_RESET       0
#define FTDI_REQ_SET_BAUD    3
#define FTDI_REQ_SET_DATA    4
#define FTDI_REQ_SET_LATENCY 9
#define FTDI_REQTYPE (USB_DIR_OUT | USB_TYPE_VENDOR | USB_RECIP_DEVICE)
#define FTDI_IFACE_A 1

#define ATOM_MAGIC 0x4B4E4C41u
#define ATOM_VERSION 1

#define MSG_HELLO       0x01
#define MSG_HELLO_ACK   0x02
#define MSG_STATUS      0x03
#define MSG_NET_FRAME   0x10
#define MSG_NET_ACK     0x11
#define MSG_PING        0x20
#define MSG_PONG        0x21
#define MSG_ERROR       0x7F

#define MAX_ETH_FRAME 1536
#define RX_STREAM_SIZE 4096
#define USB_PACKET_SIZE 64

/* SCE netdev values mirrored from PS2SDK's netdev.h. */
#define sceInetBus_NIC 5
#define sceInetDevProtVer 2
#define sceInetDevF_ARP       0x0010
#define sceInetDevF_NIC       0x0080
#define sceInetDevF_Multicast 0x0400

#define sceInetDevEFP_StartDone 0x00000001
#define sceInetDevEFP_Recv      0x00000004

#define sceInetNDCC_GET_IF_TYPE     0x80000100
#define sceInetNDCC_GET_RX_PACKETS  0x80010000
#define sceInetNDCC_GET_TX_PACKETS  0x80010001
#define sceInetNDCC_GET_RX_BYTES    0x80010002
#define sceInetNDCC_GET_TX_BYTES    0x80010003
#define sceInetNDCC_GET_RX_ERRORS   0x80010004
#define sceInetNDCC_GET_TX_ERRORS   0x80010005
#define sceInetNDCC_GET_RX_DROPPED  0x80010006
#define sceInetNDCC_GET_TX_DROPPED  0x80010007
#define sceInetNDCC_GET_NEGO_MODE   0x80020000
#define sceInetNDCC_SET_NEGO_MODE   0x81020000
#define sceInetNDCC_GET_NEGO_STATUS 0x80020001
#define sceInetNDCC_GET_LINK_STATUS 0x80030000

#define sceInetNDIFT_ETHERNET 0x00000001
#define sceInetNDNEGO_TX_FD   0x0008
#define sceInetNDNEGO_AUTO    0x0080
#define sceInetNDNEGO_PAUSE   0x0040

typedef struct __attribute__((packed)) {
    u32 magic;
    u8 version;
    u8 type;
    u16 length;
    u16 sequence;
    u16 flags;
} atom_header_t;

typedef struct sceInetPkt {
    struct sceInetPkt *forw;
    struct sceInetPkt *back;
    void *m_reserved1;
    void *m_reserved2;
    u8 *rp;
    u8 *wp;
} sceInetPkt_t;

typedef struct sceInetPktQ {
    sceInetPkt_t *head;
    sceInetPkt_t *tail;
} sceInetPktQ_t;

typedef struct sceInetDevOps {
    struct sceInetDevOps *forw;
    struct sceInetDevOps *back;
    char interface[9];
    char *module_name;
    char *vendor_name;
    char *device_name;
    u8 bus_type;
    u8 bus_loc[31];
    u16 prot_ver;
    u16 impl_ver;
    void *priv;
    int flags;
    int evfid;
    sceInetPktQ_t rcvq;
    sceInetPktQ_t sndq;
    int (*start)(void *priv, int flags);
    int (*stop)(void *priv, int flags);
    int (*xmit)(void *priv, int flags);
    int (*control)(void *priv, int code, void *ptr, int len);
    unsigned int ip_addr;
    unsigned int ip_mask;
    unsigned int broad_addr;
    unsigned int gw_addr;
    unsigned int ns_addr1;
    int mtu;
    u8 hw_addr[16];
    u8 dhcp_hostname[256];
    int dhcp_hostname_len;
    int dhcp_flags;
    void *reserved[4];
    unsigned int ns_addr2;
    void *pppoe_priv;
} sceInetDevOps_t;

typedef int (*netdev_register_t)(sceInetDevOps_t *ops);
typedef int (*netdev_unregister_t)(sceInetDevOps_t *ops);
typedef void (*netdev_pkt_enq_t)(sceInetPktQ_t *q, sceInetPkt_t *pkt);
typedef sceInetPkt_t *(*netdev_pkt_deq_t)(sceInetPktQ_t *q);
typedef sceInetPkt_t *(*netdev_alloc_pkt_t)(sceInetDevOps_t *ops, int size);
typedef void (*netdev_free_pkt_t)(sceInetDevOps_t *ops, sceInetPkt_t *pkt);

typedef struct {
    int dev_id;
    int control;
    int bulk_in;
    int bulk_out;
    u16 vid;
    u16 pid;
} atom_usb_t;

static atom_usb_t g_atom = {-1, -1, -1, -1, 0, 0};

static volatile int g_xfer_done = 0;
static volatile int g_xfer_result = 0;
static volatile int g_xfer_count = 0;
static volatile int g_device_ready = 0;
static volatile int g_transport_configured = 0;
static volatile int g_link_alive = 0;

static int g_io_sema = -1;
static int g_thread = -1;
static u16 g_sequence = 1;
static int g_config_value = 1;

static u8 g_tx[sizeof(atom_header_t) + MAX_ETH_FRAME + 4] __attribute__((aligned(64)));
static u8 g_usb_rx[USB_PACKET_SIZE] __attribute__((aligned(64)));
static u8 g_stream[RX_STREAM_SIZE];
static int g_stream_len = 0;

/* Virtual SCE Ethernet adapter state. */
static sceInetDevOps_t g_netdev;
static netdev_register_t g_nd_register = NULL;
static netdev_unregister_t g_nd_unregister = NULL;
static netdev_pkt_enq_t g_nd_enq = NULL;
static netdev_pkt_deq_t g_nd_deq = NULL;
static netdev_alloc_pkt_t g_nd_alloc = NULL;
static netdev_free_pkt_t g_nd_free = NULL;
static int g_netdev_registered = 0;
static int g_netdev_started = 0;

static unsigned int g_rx_packets = 0;
static unsigned int g_tx_packets = 0;
static unsigned int g_rx_bytes = 0;
static unsigned int g_tx_bytes = 0;
static unsigned int g_rx_dropped = 0;
static unsigned int g_tx_dropped = 0;

static int atom_probe(int devId);
static int atom_connect(int devId);
static int atom_disconnect(int devId);

static UsbDriver atom_usb_driver = {
    NULL, NULL, "atomnet-usb", atom_probe, atom_connect, atom_disconnect
};

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

    result = UsbSetDeviceConfiguration(g_atom.control, value, xfer_cb, NULL);
    return wait_xfer(result, 800);
}

static int bulk_out(const void *data, int len)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbBulkTransfer(g_atom.bulk_out, (void *)data, len, xfer_cb, NULL);
    return wait_xfer(result, 800);
}

static int bulk_in(void *data, int len, int timeout_ms)
{
    int result;

    g_xfer_done = 0;
    g_xfer_result = 0;
    g_xfer_count = 0;

    result = UsbBulkTransfer(g_atom.bulk_in, data, len, xfer_cb, NULL);
    return wait_xfer(result, timeout_ms);
}

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
        } else if (type == USB_DT_ENDPOINT && interface != NULL) {
            ep = (UsbEndpointDescriptor *)p;

            if ((ep->bmAttributes & USB_ENDPOINT_XFERTYPE_MASK) == USB_ENDPOINT_XFER_BULK) {
                if ((ep->bEndpointAddress & USB_ENDPOINT_DIR_MASK) == USB_DIR_IN) {
                    if (g_atom.bulk_in < 0)
                        g_atom.bulk_in = UsbOpenEndpointAligned(devId, ep);
                } else {
                    if (g_atom.bulk_out < 0)
                        g_atom.bulk_out = UsbOpenEndpointAligned(devId, ep);
                }
            }
        }

        p += len;
    }

    return (g_atom.bulk_in >= 0 && g_atom.bulk_out >= 0) ? 0 : -1;
}

static int configure_ftdi(void)
{
    int result;

    result = control_out(FTDI_REQ_RESET, 0, FTDI_IFACE_A);
    if (result < 0)
        return result;

    /*
     * FT232R base clock = 3 MHz. Divisor 3 gives 1,000,000 baud.
     * ESP32 UART is configured to the same rate in ATOM-Link v0.6.
     */
    result = control_out(FTDI_REQ_SET_BAUD, 3, FTDI_IFACE_A);
    if (result < 0)
        return result;

    result = control_out(FTDI_REQ_SET_DATA, 8, FTDI_IFACE_A);
    if (result < 0)
        return result;

    result = control_out(FTDI_REQ_SET_LATENCY, 1, FTDI_IFACE_A);
    if (result < 0)
        return result;

    return 0;
}

static int send_frame_locked(u8 type, const u8 *payload, u16 len, u16 sequence)
{
    atom_header_t *h;
    u32 crc;
    int total;

    if (!g_transport_configured || len > MAX_ETH_FRAME)
        return -1;

    h = (atom_header_t *)g_tx;
    h->magic = ATOM_MAGIC;
    h->version = ATOM_VERSION;
    h->type = type;
    h->length = len;
    h->sequence = sequence ? sequence : g_sequence++;
    h->flags = 0;

    if (payload != NULL && len > 0)
        memcpy(g_tx + sizeof(*h), payload, len);

    crc = 0;
    crc = crc32_update(crc, g_tx, sizeof(*h) + len);
    memcpy(g_tx + sizeof(*h) + len, &crc, sizeof(crc));

    total = sizeof(*h) + len + sizeof(crc);
    return bulk_out(g_tx, total);
}

static int stream_find_magic(void)
{
    int i;

    for (i = 0; i + 4 <= g_stream_len; i++) {
        if (g_stream[i] == 0x41 &&
            g_stream[i + 1] == 0x4C &&
            g_stream[i + 2] == 0x4E &&
            g_stream[i + 3] == 0x4B)
            return i;
    }

    return -1;
}

static void stream_drop(int count)
{
    if (count <= 0)
        return;

    if (count >= g_stream_len) {
        g_stream_len = 0;
        return;
    }

    memmove(g_stream, g_stream + count, g_stream_len - count);
    g_stream_len -= count;
}

static void deliver_ethernet_frame(const u8 *frame, int len)
{
    sceInetPkt_t *pkt;

    if (!g_netdev_registered || !g_netdev_started ||
        g_nd_alloc == NULL || g_nd_enq == NULL ||
        len <= 0 || len > MAX_ETH_FRAME) {
        g_rx_dropped++;
        return;
    }

    pkt = g_nd_alloc(&g_netdev, len);
    if (pkt == NULL || pkt->wp == NULL) {
        g_rx_dropped++;
        return;
    }

    memcpy(pkt->wp, frame, len);
    if (pkt->rp == NULL)
        pkt->rp = pkt->wp;
    pkt->wp += len;

    g_nd_enq(&g_netdev.rcvq, pkt);

    if (g_netdev.evfid > 0)
        SetEventFlag(g_netdev.evfid, sceInetDevEFP_Recv);

    g_rx_packets++;
    g_rx_bytes += len;
}

static int parse_stream_for_frames(u16 wanted_pong)
{
    int found_pong = 0;

    while (g_stream_len >= 4) {
        int pos;
        atom_header_t h;
        int total;
        u32 got_crc;
        u32 calc_crc;

        pos = stream_find_magic();
        if (pos < 0) {
            if (g_stream_len > 3)
                stream_drop(g_stream_len - 3);
            break;
        }

        if (pos > 0)
            stream_drop(pos);

        if (g_stream_len < (int)sizeof(atom_header_t))
            break;

        memcpy(&h, g_stream, sizeof(h));

        if (h.magic != ATOM_MAGIC ||
            h.version != ATOM_VERSION ||
            h.length > MAX_ETH_FRAME) {
            stream_drop(1);
            continue;
        }

        total = sizeof(h) + h.length + sizeof(u32);
        if (g_stream_len < total)
            break;

        memcpy(&got_crc, g_stream + sizeof(h) + h.length, sizeof(got_crc));
        calc_crc = crc32_update(0, g_stream, sizeof(h) + h.length);

        if (got_crc != calc_crc) {
            stream_drop(1);
            continue;
        }

        if (h.type == MSG_PONG && h.sequence == wanted_pong)
            found_pong = 1;
        else if (h.type == MSG_NET_FRAME && h.length > 0)
            deliver_ethernet_frame(g_stream + sizeof(h), h.length);

        stream_drop(total);
    }

    return found_pong;
}

static void append_ftdi_packet(const u8 *data, int len)
{
    int payload_len;

    if (len <= 2)
        return;

    /* Every FTDI bulk-IN USB packet starts with two modem-status bytes. */
    data += 2;
    payload_len = len - 2;

    if (payload_len > RX_STREAM_SIZE)
        return;

    if (g_stream_len + payload_len > RX_STREAM_SIZE) {
        int need = g_stream_len + payload_len - RX_STREAM_SIZE;
        stream_drop(need);
    }

    memcpy(g_stream + g_stream_len, data, payload_len);
    g_stream_len += payload_len;
}

static int atom_poll_once(void)
{
    int rx_len;

    memset(g_usb_rx, 0, sizeof(g_usb_rx));
    rx_len = bulk_in(g_usb_rx, sizeof(g_usb_rx), 250);
    if (rx_len <= 0)
        return rx_len;

    append_ftdi_packet(g_usb_rx, rx_len);
    parse_stream_for_frames(0);
    return rx_len;
}

static int atom_ping_locked(void)
{
    u16 seq;
    int i;

    seq = g_sequence++;

    if (send_frame_locked(MSG_PING, NULL, 0, seq) < 0)
        return -1;

    for (i = 0; i < 32; i++) {
        int rx_len;

        memset(g_usb_rx, 0, sizeof(g_usb_rx));
        rx_len = bulk_in(g_usb_rx, sizeof(g_usb_rx), 250);
        if (rx_len <= 0)
            return -2;

        append_ftdi_packet(g_usb_rx, rx_len);
        if (parse_stream_for_frames(seq))
            return 0;
    }

    return -3;
}

static const char g_netdev_libname[8] = {'n','e','t','d','e','v',0,0};

static void **find_library_exports(const char *name)
{
    iop_library_t *libptr;
    int i;

    libptr = GetLoadcoreInternalData()->let_next;
    while (libptr != NULL) {
        for (i = 0; i < 8; i++) {
            if (libptr->name[i] != name[i])
                break;
        }

        if (i == 8)
            return (void **)(((struct irx_export_table *)libptr)->fptrs);

        libptr = libptr->prev;
    }

    return NULL;
}

static int atom_netdev_start(void *priv, int flags)
{
    (void)priv;
    (void)flags;

    g_netdev_started = 1;
    if (g_netdev.evfid > 0)
        SetEventFlag(g_netdev.evfid, sceInetDevEFP_StartDone);

    printf("ATOMNET: virtual Ethernet started\n");
    return 0;
}

static int atom_netdev_stop(void *priv, int flags)
{
    (void)priv;
    (void)flags;

    g_netdev_started = 0;
    printf("ATOMNET: virtual Ethernet stopped\n");
    return 0;
}

static int atom_netdev_control(void *priv, int code, void *ptr, int len)
{
    int value = 0;

    (void)priv;

    switch (code) {
        case sceInetNDCC_GET_IF_TYPE:
            return sceInetNDIFT_ETHERNET;

        case sceInetNDCC_GET_NEGO_MODE:
        case sceInetNDCC_GET_NEGO_STATUS:
            value = sceInetNDNEGO_AUTO | sceInetNDNEGO_TX_FD | sceInetNDNEGO_PAUSE;
            break;

        case sceInetNDCC_SET_NEGO_MODE:
            return 0;

        case sceInetNDCC_GET_LINK_STATUS:
            value = g_link_alive ? 1 : 0;
            break;

        case sceInetNDCC_GET_RX_PACKETS:
            value = g_rx_packets;
            break;
        case sceInetNDCC_GET_TX_PACKETS:
            value = g_tx_packets;
            break;
        case sceInetNDCC_GET_RX_BYTES:
            value = g_rx_bytes;
            break;
        case sceInetNDCC_GET_TX_BYTES:
            value = g_tx_bytes;
            break;
        case sceInetNDCC_GET_RX_ERRORS:
        case sceInetNDCC_GET_TX_ERRORS:
            value = 0;
            break;
        case sceInetNDCC_GET_RX_DROPPED:
            value = g_rx_dropped;
            break;
        case sceInetNDCC_GET_TX_DROPPED:
            value = g_tx_dropped;
            break;

        default:
            value = 0;
            break;
    }

    if (ptr != NULL && len >= 4)
        memcpy(ptr, &value, 4);

    return 0;
}

static int atom_netdev_xmit(void *priv, int flags)
{
    sceInetPkt_t *pkt;

    (void)priv;
    (void)flags;

    if (!g_netdev_registered || g_nd_deq == NULL || g_nd_free == NULL)
        return -1;

    while ((pkt = g_nd_deq(&g_netdev.sndq)) != NULL) {
        int len;
        int result;

        if (pkt->rp == NULL || pkt->wp == NULL) {
            g_tx_dropped++;
            g_nd_free(&g_netdev, pkt);
            continue;
        }

        len = pkt->wp - pkt->rp;
        if (len <= 0 || len > MAX_ETH_FRAME || !g_link_alive) {
            g_tx_dropped++;
            g_nd_free(&g_netdev, pkt);
            continue;
        }

        WaitSema(g_io_sema);
        result = send_frame_locked(MSG_NET_FRAME, pkt->rp, (u16)len, 0);
        SignalSema(g_io_sema);

        if (result < 0)
            g_tx_dropped++;
        else {
            g_tx_packets++;
            g_tx_bytes += len;
        }

        g_nd_free(&g_netdev, pkt);
    }

    return 0;
}

static int try_register_virtual_netdev(void)
{
    void **exp;
    int result;

    if (g_netdev_registered)
        return 0;

    exp = find_library_exports(g_netdev_libname);
    if (exp == NULL)
        return -1;

    g_nd_register = (netdev_register_t)exp[4];
    g_nd_unregister = (netdev_unregister_t)exp[5];
    g_nd_enq = (netdev_pkt_enq_t)exp[8];
    g_nd_deq = (netdev_pkt_deq_t)exp[9];
    g_nd_alloc = (netdev_alloc_pkt_t)exp[12];
    g_nd_free = (netdev_free_pkt_t)exp[13];

    if (g_nd_register == NULL || g_nd_enq == NULL || g_nd_deq == NULL ||
        g_nd_alloc == NULL || g_nd_free == NULL)
        return -2;

    memset(&g_netdev, 0, sizeof(g_netdev));
    strcpy(g_netdev.interface, "smap0");
    g_netdev.module_name = "smap";
    g_netdev.vendor_name = "SCE";
    g_netdev.device_name = "Ethernet (Network Adaptor)";
    g_netdev.bus_type = sceInetBus_NIC;
    g_netdev.prot_ver = sceInetDevProtVer;
    g_netdev.impl_ver = 0;
    g_netdev.priv = &g_netdev;
    g_netdev.flags = sceInetDevF_ARP | sceInetDevF_Multicast | sceInetDevF_NIC;
    g_netdev.start = atom_netdev_start;
    g_netdev.stop = atom_netdev_stop;
    g_netdev.xmit = atom_netdev_xmit;
    g_netdev.control = atom_netdev_control;
    g_netdev.mtu = 1500;

    /* Locally administered stable MAC: 02:50:53:32:41:54 ("PS2AT"). */
    g_netdev.hw_addr[0] = 0x02;
    g_netdev.hw_addr[1] = 0x50;
    g_netdev.hw_addr[2] = 0x53;
    g_netdev.hw_addr[3] = 0x32;
    g_netdev.hw_addr[4] = 0x41;
    g_netdev.hw_addr[5] = 0x54;

    result = g_nd_register(&g_netdev);
    if (result < 0)
        return result;

    g_netdev_registered = 1;
    printf("ATOMNET: registered virtual SCE Ethernet adapter\n");
    return 0;
}

static void AtomWorkerThread(void *arg)
{
    int result;
    int netdev_announced = 0;

    (void)arg;

    while (1) {
        if (g_device_ready) {
            if (!g_transport_configured) {
                DelayThread(250000);

                WaitSema(g_io_sema);
                result = set_configuration(g_config_value);
                if (result >= 0)
                    result = configure_ftdi();
                SignalSema(g_io_sema);

                if (result < 0) {
                    DelayThread(500000);
                    continue;
                }

                g_transport_configured = 1;
                printf("ATOMNET: FTDI @ 1,000,000 baud\n");
            }

            WaitSema(g_io_sema);
            result = atom_ping_locked();
            SignalSema(g_io_sema);

            g_link_alive = (result == 0);

            if (g_link_alive) {
                if (try_register_virtual_netdev() == 0 && !netdev_announced) {
                    netdev_announced = 1;
                    printf("ATOMNET: VirtualNIC ready\n");
                }
            }
        } else {
            g_link_alive = 0;
        }

        /*
         * 20 ms polling gives inbound packets a bounded latency while keeping
         * IOP usage reasonable. Network traffic itself is sent immediately.
         */
        DelayThread(g_netdev_registered ? 10000 : 5000);
    }
}

static int atom_probe(int devId)
{
    UsbDeviceDescriptor *device;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(devId, NULL, USB_DT_DEVICE);
    if (device == NULL)
        return 0;

    if (device->idVendor != VID_FTDI ||
        (device->idProduct != PID_FT232R && device->idProduct != PID_FT231X))
        return 0;

    return 1;
}

static int atom_connect(int devId)
{
    UsbDeviceDescriptor *device;
    UsbConfigDescriptor *config;

    if (g_atom.dev_id >= 0)
        return 1;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(devId, NULL, USB_DT_DEVICE);
    if (device == NULL)
        return 1;

    config = (UsbConfigDescriptor *)UsbGetDeviceStaticDescriptor(devId, device, USB_DT_CONFIG);
    if (config == NULL)
        return 1;

    g_atom.dev_id = devId;
    g_atom.vid = device->idVendor;
    g_atom.pid = device->idProduct;
    g_atom.control = UsbOpenEndpoint(devId, NULL);
    g_atom.bulk_in = -1;
    g_atom.bulk_out = -1;
    g_device_ready = 0;
    g_transport_configured = 0;
    g_link_alive = 0;
    g_config_value = config->bConfigurationValue;

    if (open_ftdi_endpoints(devId, config) < 0 ||
        g_atom.control < 0 || g_atom.bulk_in < 0 || g_atom.bulk_out < 0) {
        atom_disconnect(devId);
        return 1;
    }

    g_device_ready = 1;
    printf("ATOMNET: FTDI %04X:%04X attached dev=%d\n",
           g_atom.vid, g_atom.pid, devId);

    return 0;
}

static int atom_disconnect(int devId)
{
    g_device_ready = 0;
    g_transport_configured = 0;
    g_link_alive = 0;

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

    return 0;
}

int _start(int argc, char *argv[])
{
    int result;
    iop_thread_t thread;
    iop_sema_t sema;

    (void)argc;
    (void)argv;

    printf("ATOMNET v0.6 VirtualNIC starting\n");

    sema.attr = 0;
    sema.option = 0;
    sema.initial = 1;
    sema.max = 1;
    g_io_sema = CreateSema(&sema);
    if (g_io_sema < 0)
        return MODULE_NO_RESIDENT_END;

    result = UsbRegisterDriver(&atom_usb_driver);
    if (result < 0)
        return MODULE_NO_RESIDENT_END;

    thread.attr = TH_C;
    thread.option = 0;
    thread.thread = &AtomWorkerThread;
    thread.priority = 0x2f;
    thread.stacksize = 0x1800;

    g_thread = CreateThread(&thread);
    if (g_thread > 0)
        StartThread(g_thread, NULL);
    else
        return MODULE_NO_RESIDENT_END;

    return MODULE_RESIDENT_END;
}
