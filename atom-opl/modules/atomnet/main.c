#include <types.h>
#include <loadcore.h>
#include <stdio.h>
#include <sysclib.h>
#include <thbase.h>
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

#define MSG_HELLO         0x01
#define MSG_HELLO_ACK     0x02
#define MSG_STATUS        0x03
#define MSG_NET_FRAME     0x10
#define MSG_NET_FRAME_ACK 0x11
#define MSG_PING          0x20
#define MSG_PONG          0x21
#define MSG_ERROR         0x7F

#define ATOM_MAX_PAYLOAD 1600
#define ATOM_TX_SIZE (12 + ATOM_MAX_PAYLOAD + 4)
#define ATOM_STREAM_SIZE 4096
#define FTDI_USB_PACKET 64

/* SCE INET netdev constants. Kept local so atomnet can bind dynamically
 * after a game's INET stack appears, without importing netdev at module load. */
#define sceInetBus_NIC 5
#define sceInetDevProtVer 2

#define sceInetDevF_Up        0x0001
#define sceInetDevF_Running   0x0002
#define sceInetDevF_Broadcast 0x0004
#define sceInetDevF_ARP       0x0010
#define sceInetDevF_DHCP      0x0020
#define sceInetDevF_NIC       0x0080
#define sceInetDevF_Multicast 0x0400

#define sceInetDevEFP_StartDone 0x00000001
#define sceInetDevEFP_PlugOut   0x00000002
#define sceInetDevEFP_Recv      0x00000004

#define sceInetNDCC_GET_THPRI        0x80000000
#define sceInetNDCC_SET_THPRI        0x81000000
#define sceInetNDCC_GET_IF_TYPE      0x80000100
#define sceInetNDCC_GET_RX_PACKETS   0x80010000
#define sceInetNDCC_GET_TX_PACKETS   0x80010001
#define sceInetNDCC_GET_RX_BYTES     0x80010002
#define sceInetNDCC_GET_TX_BYTES     0x80010003
#define sceInetNDCC_GET_RX_ERRORS    0x80010004
#define sceInetNDCC_GET_TX_ERRORS    0x80010005
#define sceInetNDCC_GET_RX_DROPPED   0x80010006
#define sceInetNDCC_GET_TX_DROPPED   0x80010007
#define sceInetNDCC_GET_NEGO_MODE    0x80020000
#define sceInetNDCC_SET_NEGO_MODE    0x81020000
#define sceInetNDCC_GET_NEGO_STATUS  0x80020001
#define sceInetNDCC_GET_LINK_STATUS  0x80030000
#define sceInetNDCC_SET_MULTICAST_LIST 0x81040000

#define sceInetNDIFT_ETHERNET 0x00000001

#define sceInetNDNEGO_10     0x0001
#define sceInetNDNEGO_10_FD  0x0002
#define sceInetNDNEGO_TX     0x0004
#define sceInetNDNEGO_TX_FD  0x0008
#define sceInetNDNEGO_PAUSE  0x0040
#define sceInetNDNEGO_AUTO   0x0080

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
} atom_usb_t;

typedef struct sceInetPkt {
    struct sceInetPkt *forw;
    struct sceInetPkt *back;
    void *m_reserved1;
    void *m_reserved2;
    u8 *rp;
    u8 *wp;
} sceInetPkt_t;

typedef struct sceInetPktQ {
    struct sceInetPkt *head;
    struct sceInetPkt *tail;
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

typedef int (*netdev_register_fn)(sceInetDevOps_t *ops);
typedef int (*netdev_unregister_fn)(sceInetDevOps_t *ops);
typedef void (*netdev_pkt_enq_fn)(sceInetPktQ_t *que, sceInetPkt_t *pkt);
typedef sceInetPkt_t *(*netdev_pkt_deq_fn)(sceInetPktQ_t *que);
typedef sceInetPkt_t *(*netdev_alloc_pkt_fn)(sceInetDevOps_t *ops, int siz);
typedef void (*netdev_free_pkt_fn)(sceInetDevOps_t *ops, sceInetPkt_t *pkt);

static atom_usb_t g_atom = {-1, -1, -1, -1, 0, 0};

static volatile int g_xfer_done = 0;
static volatile int g_xfer_result = 0;
static volatile int g_xfer_count = 0;

static volatile int g_rx_pending = 0;
static volatile int g_rx_done = 0;
static volatile int g_rx_result = 0;
static volatile int g_rx_count = 0;

static volatile int g_device_ready = 0;
static volatile int g_transport_configured = 0;
static volatile int g_link_alive = 0;
static volatile int g_config_value = 1;
static volatile int g_tx_requested = 0;

static u8 g_tx[ATOM_TX_SIZE] __attribute__((aligned(64)));
static u8 g_usb_rx[FTDI_USB_PACKET] __attribute__((aligned(64)));
static u8 g_stream[ATOM_STREAM_SIZE] __attribute__((aligned(64)));
static int g_stream_len = 0;

static u16 g_sequence = 1;
static u16 g_last_ping_sequence = 0;
static int g_transport_thread = -1;

/* Dynamic SCE INET netdev binding. */
static netdev_register_fn g_nd_register = NULL;
static netdev_unregister_fn g_nd_unregister = NULL;
static netdev_pkt_enq_fn g_nd_enq = NULL;
static netdev_pkt_deq_fn g_nd_deq = NULL;
static netdev_alloc_pkt_fn g_nd_alloc = NULL;
static netdev_free_pkt_fn g_nd_free = NULL;
static sceInetDevOps_t g_nic;
static volatile int g_netdev_bound = 0;
static volatile int g_netdev_registered = 0;

static unsigned int g_tx_packets = 0;
static unsigned int g_rx_packets = 0;
static unsigned int g_tx_bytes = 0;
static unsigned int g_rx_bytes = 0;
static unsigned int g_tx_dropped = 0;
static unsigned int g_rx_dropped = 0;

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

static void rx_cb(int result, int count, void *arg)
{
    (void)arg;
    g_rx_result = result;
    g_rx_count = count;
    g_rx_done = 1;
    g_rx_pending = 0;
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

    return wait_xfer(result, 1000);
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

static int send_atom_frame(u8 type, const void *payload, int len, u16 sequence)
{
    atom_header_t *h;
    u32 crc;
    int total;

    if (!g_transport_configured || len < 0 || len > ATOM_MAX_PAYLOAD)
        return -1;

    h = (atom_header_t *)g_tx;
    h->magic = ATOM_MAGIC;
    h->version = ATOM_VERSION;
    h->type = type;
    h->length = (u16)len;
    h->sequence = sequence ? sequence : g_sequence++;
    h->flags = 0;

    if (len > 0 && payload != NULL)
        memcpy(g_tx + sizeof(*h), payload, len);

    crc = crc32_update(0, g_tx, sizeof(*h));
    if (len > 0)
        crc = crc32_update(crc, g_tx + sizeof(*h), len);

    memcpy(g_tx + sizeof(*h) + len, &crc, sizeof(crc));
    total = sizeof(*h) + len + sizeof(crc);

    return bulk_out(g_tx, total);
}

static int configure_ftdi(void)
{
    int result;

    result = control_out(FTDI_REQ_RESET, 0, FTDI_IFACE_A);
    if (result < 0)
        return result;

    /* 115200 baud. v0.7 can negotiate a turbo baud after packet routing works. */
    result = control_out(FTDI_REQ_SET_BAUD, 26, FTDI_IFACE_A);
    if (result < 0)
        return result;

    result = control_out(FTDI_REQ_SET_DATA, 8, FTDI_IFACE_A); /* 8N1 */
    if (result < 0)
        return result;

    result = control_out(FTDI_REQ_SET_LATENCY, 1, FTDI_IFACE_A);
    if (result < 0)
        return result;

    return 0;
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

            if ((ep->bmAttributes & USB_ENDPOINT_XFERTYPE_MASK) ==
                USB_ENDPOINT_XFER_BULK) {
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

static void arm_usb_rx(void)
{
    int result;

    if (!g_transport_configured || g_atom.bulk_in < 0 ||
        g_rx_pending || g_rx_done)
        return;

    memset(g_usb_rx, 0, sizeof(g_usb_rx));
    g_rx_result = 0;
    g_rx_count = 0;
    g_rx_pending = 1;

    result = UsbBulkTransfer(
        g_atom.bulk_in,
        g_usb_rx,
        sizeof(g_usb_rx),
        rx_cb,
        NULL);

    if (result < 0) {
        g_rx_pending = 0;
        g_rx_result = result;
    }
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

static int atom_nic_start(void *priv, int flags)
{
    (void)priv;
    (void)flags;

    g_nic.flags |= (sceInetDevF_Up | sceInetDevF_Running);
    if (g_nic.evfid > 0)
        SetEventFlag(g_nic.evfid, sceInetDevEFP_StartDone);

    return 0;
}

static int atom_nic_stop(void *priv, int flags)
{
    (void)priv;
    (void)flags;

    g_nic.flags &= ~(sceInetDevF_Up | sceInetDevF_Running);
    return 0;
}

static int atom_nic_xmit(void *priv, int flags)
{
    (void)priv;
    (void)flags;
    g_tx_requested = 1;
    return 0;
}

static int atom_nic_control(void *priv, int code, void *ptr, int len)
{
    unsigned int value = 0;

    (void)priv;

    switch (code) {
        case sceInetNDCC_GET_IF_TYPE:
            return sceInetNDIFT_ETHERNET;

        case sceInetNDCC_GET_LINK_STATUS:
            return g_link_alive ? 1 : 0;

        case sceInetNDCC_GET_NEGO_STATUS:
            return g_link_alive ? sceInetNDNEGO_TX_FD : 0;

        case sceInetNDCC_GET_NEGO_MODE:
            value = sceInetNDNEGO_AUTO | sceInetNDNEGO_TX_FD |
                    sceInetNDNEGO_TX | sceInetNDNEGO_10_FD |
                    sceInetNDNEGO_10 | sceInetNDNEGO_PAUSE;
            if (ptr != NULL && len >= 4)
                memcpy(ptr, &value, 4);
            return 0;

        case sceInetNDCC_SET_NEGO_MODE:
        case sceInetNDCC_SET_MULTICAST_LIST:
            return 0;

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
        case sceInetNDCC_GET_RX_DROPPED:
            value = g_rx_dropped;
            break;
        case sceInetNDCC_GET_TX_ERRORS:
        case sceInetNDCC_GET_TX_DROPPED:
            value = g_tx_dropped;
            break;

        case sceInetNDCC_GET_THPRI:
            value = 0x2f;
            break;
        case sceInetNDCC_SET_THPRI:
            return 0;

        default:
            value = 0;
            break;
    }

    if (ptr != NULL && len >= 4)
        memcpy(ptr, &value, 4);

    return 0;
}

static int bind_netdev_library(void)
{
    iop_library_t *libptr;
    void **exports;

    if (g_netdev_bound)
        return 1;

    libptr = GetLoadcoreInternalData()->let_next;

    while (libptr != NULL) {
        if (strncmp(libptr->name, "netdev", 6) == 0) {
            exports = (void **)(((struct irx_export_table *)libptr)->fptrs);

            g_nd_register = (netdev_register_fn)exports[4];
            g_nd_unregister = (netdev_unregister_fn)exports[5];
            g_nd_enq = (netdev_pkt_enq_fn)exports[8];
            g_nd_deq = (netdev_pkt_deq_fn)exports[9];
            g_nd_alloc = (netdev_alloc_pkt_fn)exports[12];
            g_nd_free = (netdev_free_pkt_fn)exports[13];

            if (g_nd_register && g_nd_enq && g_nd_deq &&
                g_nd_alloc && g_nd_free) {
                g_netdev_bound = 1;
                printf("ATOMNET: SCE netdev library bound\n");
                return 1;
            }
        }

        libptr = libptr->prev;
    }

    return 0;
}

static int register_virtual_nic(void)
{
    int result;

    if (g_netdev_registered)
        return 1;

    if (!g_netdev_bound && !bind_netdev_library())
        return 0;

    memset(&g_nic, 0, sizeof(g_nic));

    g_nic.interface[0] = 's';
    g_nic.interface[1] = 'm';
    g_nic.interface[2] = 'a';
    g_nic.interface[3] = 'p';
    g_nic.interface[4] = '0';
    g_nic.interface[5] = '\0';

    g_nic.module_name = "smap";
    g_nic.vendor_name = "SCE";
    g_nic.device_name = "Ethernet (Network Adaptor)";
    g_nic.bus_type = sceInetBus_NIC;
    g_nic.prot_ver = sceInetDevProtVer;
    g_nic.impl_ver = 0x0001;
    g_nic.priv = &g_nic;
    g_nic.flags = sceInetDevF_Broadcast | sceInetDevF_ARP |
                  sceInetDevF_DHCP | sceInetDevF_NIC |
                  sceInetDevF_Multicast;
    g_nic.start = atom_nic_start;
    g_nic.stop = atom_nic_stop;
    g_nic.xmit = atom_nic_xmit;
    g_nic.control = atom_nic_control;
    g_nic.mtu = 1500;

    /* Locally administered MAC used by the virtual PS2 adapter. */
    g_nic.hw_addr[0] = 0x02;
    g_nic.hw_addr[1] = 0x4B;
    g_nic.hw_addr[2] = 0x4E;
    g_nic.hw_addr[3] = 0x4C;
    g_nic.hw_addr[4] = 0x00;
    g_nic.hw_addr[5] = 0x02;

    result = g_nd_register(&g_nic);
    if (result == 0) {
        g_netdev_registered = 1;
        printf("ATOMNET: virtual SCE Ethernet adapter registered\n");
        return 1;
    }

    printf("ATOMNET: sceInetRegisterNetDevice -> %d\n", result);
    return 0;
}

static void deliver_network_frame(const u8 *data, int len)
{
    sceInetPkt_t *pkt;

    if (!g_netdev_registered || !g_nd_alloc || !g_nd_enq ||
        len <= 0 || len > 1518) {
        g_rx_dropped++;
        return;
    }

    pkt = g_nd_alloc(&g_nic, len);
    if (pkt == NULL || pkt->wp == NULL) {
        g_rx_dropped++;
        return;
    }

    memcpy(pkt->wp, data, len);
    pkt->wp += len;

    g_nd_enq(&g_nic.rcvq, pkt);

    if (g_nic.evfid > 0)
        SetEventFlag(g_nic.evfid, sceInetDevEFP_Recv);

    g_rx_packets++;
    g_rx_bytes += len;
}

static void process_atom_frame(const atom_header_t *h, const u8 *payload)
{
    switch (h->type) {
        case MSG_PONG:
            if (h->sequence == g_last_ping_sequence)
                g_link_alive = 1;
            break;

        case MSG_NET_FRAME:
            deliver_network_frame(payload, h->length);
            break;

        case MSG_HELLO_ACK:
        case MSG_STATUS:
        case MSG_NET_FRAME_ACK:
        case MSG_ERROR:
        default:
            break;
    }
}

static void parse_stream(void)
{
    int pos;
    atom_header_t h;
    int total;
    u32 rx_crc;
    u32 crc;

    while (g_stream_len >= 4) {
        pos = stream_find_magic();

        if (pos < 0) {
            if (g_stream_len > 3)
                stream_drop(g_stream_len - 3);
            return;
        }

        if (pos > 0)
            stream_drop(pos);

        if (g_stream_len < (int)sizeof(atom_header_t))
            return;

        memcpy(&h, g_stream, sizeof(h));

        if (h.magic != ATOM_MAGIC ||
            h.version != ATOM_VERSION ||
            h.length > ATOM_MAX_PAYLOAD) {
            stream_drop(1);
            continue;
        }

        total = sizeof(atom_header_t) + h.length + 4;
        if (g_stream_len < total)
            return;

        memcpy(&rx_crc, g_stream + sizeof(atom_header_t) + h.length, 4);

        crc = crc32_update(0, g_stream, sizeof(atom_header_t));
        if (h.length > 0)
            crc = crc32_update(crc, g_stream + sizeof(atom_header_t), h.length);

        if (crc != rx_crc) {
            stream_drop(1);
            continue;
        }

        process_atom_frame(&h, g_stream + sizeof(atom_header_t));
        stream_drop(total);
    }
}

static void poll_usb_rx(void)
{
    int data_len;

    if (!g_rx_done)
        return;

    g_rx_done = 0;

    if (g_rx_result == USB_RC_OK && g_rx_count > 2) {
        /*
         * One 64-byte FTDI USB IN packet at a time: first two bytes are modem
         * status, remaining bytes are UART payload.
         */
        data_len = g_rx_count - 2;

        if (data_len > 0) {
            if (g_stream_len + data_len > ATOM_STREAM_SIZE) {
                int remove = (g_stream_len + data_len) - ATOM_STREAM_SIZE;
                stream_drop(remove);
            }

            memcpy(g_stream + g_stream_len, g_usb_rx + 2, data_len);
            g_stream_len += data_len;
            parse_stream();
        }
    }

    arm_usb_rx();
}

static void drain_network_tx(void)
{
    sceInetPkt_t *pkt;
    int len;
    int sent;
    int budget = 4;

    if (!g_netdev_registered || !g_nd_deq || !g_nd_free ||
        !g_link_alive || !g_transport_configured)
        return;

    while (budget-- > 0) {
        pkt = g_nd_deq(&g_nic.sndq);
        if (pkt == NULL)
            break;

        len = (int)(pkt->wp - pkt->rp);

        if (len > 0 && len <= 1518) {
            sent = send_atom_frame(MSG_NET_FRAME, pkt->rp, len, 0);
            if (sent >= 0) {
                g_tx_packets++;
                g_tx_bytes += len;
            } else {
                g_tx_dropped++;
            }
        } else {
            g_tx_dropped++;
        }

        g_nd_free(&g_nic, pkt);
    }

    g_tx_requested = 0;
}

static void TransportThread(void *arg)
{
    int result;
    int ticks = 0;
    int netdev_ticks = 0;

    (void)arg;

    while (1) {
        if (!g_device_ready) {
            g_link_alive = 0;
            DelayThread(10000);
            continue;
        }

        if (!g_transport_configured) {
            DelayThread(250000);

            result = set_configuration(g_config_value);
            if (result < 0) {
                printf("ATOMNET: deferred SET_CONFIGURATION failed %d\n", result);
                DelayThread(500000);
                continue;
            }

            result = configure_ftdi();
            if (result < 0) {
                printf("ATOMNET: deferred FTDI setup failed %d\n", result);
                DelayThread(500000);
                continue;
            }

            g_transport_configured = 1;
            g_link_alive = 0;
            g_stream_len = 0;
            printf("ATOMNET: FTDI transport configured\n");
            arm_usb_rx();
        }

        poll_usb_rx();
        arm_usb_rx();

        if (++ticks >= 500) {
            ticks = 0;
            g_last_ping_sequence = g_sequence++;
            send_atom_frame(MSG_PING, NULL, 0, g_last_ping_sequence);
        }

        if (++netdev_ticks >= 50) {
            netdev_ticks = 0;
            if (!g_netdev_registered)
                register_virtual_nic();
        }

        if (g_tx_requested || g_netdev_registered)
            drain_network_tx();

        DelayThread(2000);
    }
}

static int atom_probe(int devId)
{
    UsbDeviceDescriptor *device;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_DEVICE);

    if (device == NULL)
        return 0;

    if (device->idVendor != VID_FTDI ||
        (device->idProduct != PID_FT232R &&
         device->idProduct != PID_FT231X))
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
    g_atom.control = UsbOpenEndpoint(devId, NULL);
    g_atom.bulk_in = -1;
    g_atom.bulk_out = -1;

    g_device_ready = 0;
    g_transport_configured = 0;
    g_link_alive = 0;
    g_config_value = config->bConfigurationValue;
    g_rx_pending = 0;
    g_rx_done = 0;

    result = open_ftdi_endpoints(devId, config);
    if (result < 0 ||
        g_atom.control < 0 ||
        g_atom.bulk_in < 0 ||
        g_atom.bulk_out < 0) {
        printf("ATOMNET: FTDI endpoints missing ctl=%d in=%d out=%d\n",
               g_atom.control, g_atom.bulk_in, g_atom.bulk_out);
        atom_disconnect(devId);
        return 1;
    }

    g_device_ready = 1;

    printf("ATOMNET: FTDI attached %04X:%04X dev=%d\n",
           g_atom.vid, g_atom.pid, devId);

    return 0;
}

static int atom_disconnect(int devId)
{
    g_device_ready = 0;
    g_transport_configured = 0;
    g_link_alive = 0;
    g_rx_pending = 0;
    g_rx_done = 0;

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

    printf("ATOMNET: FTDI disconnected\n");
    return 0;
}

int _start(int argc, char *argv[])
{
    int result;
    iop_thread_t thread;

    (void)argc;
    (void)argv;

    printf("ATOMNET v0.6 VirtualNIC: starting\n");

    result = UsbRegisterDriver(&atom_usb_driver);
    if (result < 0) {
        printf("ATOMNET: UsbRegisterDriver failed %d\n", result);
        return MODULE_NO_RESIDENT_END;
    }

    thread.attr = TH_C;
    thread.option = 0;
    thread.thread = &TransportThread;
    thread.priority = 0x2f;
    thread.stacksize = 0x1800;

    g_transport_thread = CreateThread(&thread);
    if (g_transport_thread > 0)
        StartThread(g_transport_thread, NULL);
    else {
        printf("ATOMNET: transport thread create failed %d\n",
               g_transport_thread);
        return MODULE_NO_RESIDENT_END;
    }

    return MODULE_RESIDENT_END;
}
