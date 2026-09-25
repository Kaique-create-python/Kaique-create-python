#include <types.h>
#include <loadcore.h>
#include <stdio.h>
#include <sysclib.h>
#include <usbd.h>
#include <usbd_macro.h>
#include <irx.h>

IRX_ID("atomnet", 1, 0);

#define VID_SILABS 0x10C4
#define PID_CP210X 0xEA60
#define PID_CP2105 0xEA70

#define VID_WCH    0x1A86
#define PID_CH340  0x7523
#define PID_CH341  0x5523
#define PID_CH9102 0x55D4

typedef struct {
    int dev_id;
    int control;
    int bulk_in;
    int bulk_out;
    u16 vid;
    u16 pid;
} atom_usb_t;

static atom_usb_t g_atom = {-1, -1, -1, -1, 0, 0};

static int atom_probe(int devId);
static int atom_connect(int devId);
static int atom_disconnect(int devId);

static UsbDriver atom_usb_driver = {
    NULL, NULL, "atomnet-usb", atom_probe, atom_connect, atom_disconnect
};

static int is_supported(u16 vid, u16 pid)
{
    if (vid == VID_SILABS && (pid == PID_CP210X || pid == PID_CP2105))
        return 1;

    if (vid == VID_WCH && (pid == PID_CH340 || pid == PID_CH341 || pid == PID_CH9102))
        return 1;

    return 0;
}

static int atom_probe(int devId)
{
    UsbDeviceDescriptor *device;

    device = (UsbDeviceDescriptor *)UsbGetDeviceStaticDescriptor(
        devId, NULL, USB_DT_DEVICE);

    if (device == NULL)
        return 0;

    if (!is_supported(device->idVendor, device->idProduct))
        return 0;

    printf("ATOMNET: USB-UART candidate %04X:%04X dev=%d\n",
           device->idVendor, device->idProduct, devId);

    return 1;
}

static int atom_connect(int devId)
{
    UsbDeviceDescriptor *device;
    UsbConfigDescriptor *config;
    UsbEndpointDescriptor *endpoint;
    int i;

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

    printf("ATOMNET: connected vid=%04X pid=%04X ctl=%d in=%d out=%d\n",
           g_atom.vid, g_atom.pid, g_atom.control, g_atom.bulk_in, g_atom.bulk_out);

    UsbSetDeviceConfiguration(g_atom.control, config->bConfigurationValue, NULL, NULL);

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

    printf("ATOMNET: USB-UART disconnected\n");
    return 0;
}

int _start(int argc, char *argv[])
{
    int result;

    printf("ATOMNET v0.1: starting USB-UART detector\n");

    result = UsbRegisterDriver(&atom_usb_driver);
    if (result < 0) {
        printf("ATOMNET: UsbRegisterDriver failed %d\n", result);
        return MODULE_NO_RESIDENT_END;
    }

    return MODULE_RESIDENT_END;
}
