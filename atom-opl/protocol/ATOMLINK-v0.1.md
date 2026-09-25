# ATOMLINK protocol v0.1

Transport for the first hardware milestone is the ATOM Echo's USB-to-UART bridge.

The PS2 is the USB host. The ATOM's USB/UART bridge is the USB device.

## Goals

1. Detect the ATOM USB-UART chip from an in-game IOP module.
2. Keep the module resident across OPL-intercepted IOP resets.
3. Establish a framed UART link.
4. After the physical link is verified, carry virtual-network packets and add routing/NAT on the ESP32.

## Frame format (planned)

Little-endian:

- magic: 4 bytes: `ALNK`
- version: u8
- type: u8
- payload_length: u16
- sequence: u16
- flags: u16
- payload: N bytes
- crc32: u32

Initial message types:

- 0x01 HELLO
- 0x02 HELLO_ACK
- 0x03 STATUS
- 0x10 NET_FRAME
- 0x11 NET_FRAME_ACK
- 0x20 PING
- 0x21 PONG

The protocol is intentionally independent of OPL's UI so the in-game module can remain small.
