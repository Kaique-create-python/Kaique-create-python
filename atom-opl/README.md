# ATOM OPL

Experimental Open PS2 Loader build for the M5Stack ATOM Echo.

Target path:

Phone hotspot -> ATOM Echo Wi-Fi -> ATOM USB/UART -> PS2 USB host -> in-game ATOMNET module.

This branch builds from the current official Open PS2 Loader source at build time and applies the ATOM integration patch.

## Current milestone: v0.2

- Builds from official Open PS2 Loader master.
- Keeps normal OPL USB game loading.
- Adds an in-game `atomnet.irx` module to OPL's module store.
- v0.2 detects the ATOM Echo FTDI USB-UART bridge and performs an ATOMLINK PING/PONG handshake.
- Loads USBD + ATOMNET after each intercepted IOP reset.
- ATOMNET probes common CP210x and WCH CH9102/CH34x USB-UART IDs.
- Produces a versioned `ATOM-OPL-v0.1.ELF`.

The first hardware test is detection/residency. Full game networking over the ATOM tunnel is the next layer and must not be claimed working until tested on the real PS2 + ATOM.
