#!/usr/bin/env python3
from pathlib import Path
import shutil

ROOT = Path("Open-PS2-Loader")
SRC = Path("atom-opl")

def replace(path, old, new):
    p = ROOT / path
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"Patch anchor not found in {path}: {old[:80]!r}")
    p.write_text(s.replace(old, new, 1))

# Copy the ATOMNET IRX source into the official OPL tree.
dst = ROOT / "modules/network/atomnet"
if dst.exists():
    shutil.rmtree(dst)
shutil.copytree(SRC / "modules/atomnet", dst)

# Embed atomnet.irx into the EE-side module store.
replace(
    "Makefile",
    "hdd_cdvdman.o hdd_hdpro_cdvdman.o cdvdfsv.o \\\n\t\tingame_smstcpip.o smap_ingame.o smbman.o smbinit.o",
    "hdd_cdvdman.o hdd_hdpro_cdvdman.o cdvdfsv.o \\\n\t\tingame_smstcpip.o smap_ingame.o atomnet_ingame.o smbman.o smbinit.o"
)

replace(
    "Makefile",
    "$(EE_ASM_DIR)smap_ingame.c: modules/network/smap-ingame/smap.irx | $(EE_ASM_DIR)\n\t$(BIN2C) $< $@ $(*F)_irx\n",
    "$(EE_ASM_DIR)smap_ingame.c: modules/network/smap-ingame/smap.irx | $(EE_ASM_DIR)\n\t$(BIN2C) $< $@ $(*F)_irx\n\n"
    "modules/network/atomnet/atomnet.irx: modules/network/atomnet\n\t$(MAKE) -C $<\n\n"
    "$(EE_ASM_DIR)atomnet_ingame.c: modules/network/atomnet/atomnet.irx | $(EE_ASM_DIR)\n\t$(BIN2C) $< $@ $(*F)_irx\n"
)

replace(
    "Makefile",
    '\techo " -in-game SMAP"\n\t$(MAKE) -C modules/network/smap-ingame clean\n',
    '\techo " -in-game SMAP"\n\t$(MAKE) -C modules/network/smap-ingame clean\n'
    '\techo " -ATOMNET"\n\t$(MAKE) -C modules/network/atomnet clean\n'
)

# Expose the embedded atomnet IRX symbols to system.c.
replace(
    "include/extern_irx.h",
    "IMPORT_BIN2C(apemodpatch_irx);\n",
    "IMPORT_BIN2C(apemodpatch_irx);\n\nIMPORT_BIN2C(atomnet_ingame_irx);\n"
)

# Allocate a module ID for the resident ATOM link module.
replace(
    "ee_core/include/modules.h",
    "    OPL_MODULE_ID_SMBINIT,\n\n    // VMC module",
    "    OPL_MODULE_ID_SMBINIT,\n    OPL_MODULE_ID_ATOMNET,\n\n    // VMC module"
)

# Store ATOMNET when launching USB games.
replace(
    "src/system.c",
    "#define CORE_IRX_MX4SIO 0x100",
    "#define CORE_IRX_MX4SIO 0x100\n#define CORE_IRX_ATOMNET 0x200"
)

replace(
    "src/system.c",
    '    if (!strcmp(mode_str, "BDM_USB_MODE"))\n        modules |= CORE_IRX_USB;',
    '    if (!strcmp(mode_str, "BDM_USB_MODE"))\n        modules |= CORE_IRX_USB | CORE_IRX_ATOMNET;'
)

replace(
    "src/system.c",
    "    if (modules & CORE_IRX_USB) {\n"
    "        irxptr_tab[modcount].info = size_usbmass_bd_irx | SET_OPL_MOD_ID(OPL_MODULE_ID_USBMASSBD);\n"
    "        irxptr_tab[modcount++].ptr = (void *)&usbmass_bd_irx;\n"
    "    }",
    "    if (modules & CORE_IRX_USB) {\n"
    "        irxptr_tab[modcount].info = size_usbmass_bd_irx | SET_OPL_MOD_ID(OPL_MODULE_ID_USBMASSBD);\n"
    "        irxptr_tab[modcount++].ptr = (void *)&usbmass_bd_irx;\n"
    "    }\n"
    "    if (modules & CORE_IRX_ATOMNET) {\n"
    "        irxptr_tab[modcount].info = size_atomnet_ingame_irx | SET_OPL_MOD_ID(OPL_MODULE_ID_ATOMNET);\n"
    "        irxptr_tab[modcount++].ptr = (void *)&atomnet_ingame_irx;\n"
    "    }"
)

# Load ATOMNET while the OPL USB menu is running too.
# This makes the ATOM LED a direct USB diagnostic before a game is launched.
replace(
    "src/bdmsupport.c",
    "    LOG(\"[USBMASS_BD]:\\n\");\n"
    "    sysLoadModuleBuffer(&usbmass_bd_irx, size_usbmass_bd_irx, 0, NULL);\n",
    "    LOG(\"[USBMASS_BD]:\\n\");\n"
    "    sysLoadModuleBuffer(&usbmass_bd_irx, size_usbmass_bd_irx, 0, NULL);\n"
    "    LOG(\"[ATOMNET]:\\n\");\n"
    "    sysLoadModuleBuffer(&atomnet_ingame_irx, size_atomnet_ingame_irx, 0, NULL);\n"
)

# Reload ATOMNET after every IOP reset performed by a USB-loaded game.
replace(
    "ee_core/src/iopmgr.c",
    "        case BDM_USB_MODE:\n"
    "            LoadOPLModule(OPL_MODULE_ID_USBMASSBD, 0, 0, NULL);\n"
    "            break;",
    "        case BDM_USB_MODE:\n"
    "            LoadOPLModule(OPL_MODULE_ID_USBMASSBD, 0, 0, NULL);\n"
    "            LoadOPLModule(OPL_MODULE_ID_ATOMNET, 0, 0, NULL);\n"
    "            break;"
)

print("ATOM OPL patches applied.")
