# merlin-v2

`merlin-v2` is a 68k-based FPGA computer project centered on a pipelined 68030 system (`nex030`) with HyperRAM, Quad-SPI flash/XIP, and an MC68901-compatible MFP peripheral set.

## Current scope

Implemented in this repository:
- Pipelined 68030 CPU integration (`68K30L/*`, wired in `nex030.vhd`)
- MC68901-compatible MFP integration with UART/timers/GPIO (`MFP68901/*`)
- HyperRAM controller and system memory path (`rtl/memory/hyperram.vhd`)
- Quad-SPI flash interface for ROM/XIP paths (`rtl/storage/spi_flash.vhd`)
- Top-level board wrapper and clock/reset startup logic (`rtl/top/main.vhd`, entity `top_level`)
- Monitor/BIOS and boot/utility assembly sources and images (`firmware/bios/*`, `firmware/roms/*`)
- CPM-related disk/ramdrive images in S-record form (`images/cpm/*`)

## Repository layout

- `rtl/top/main.vhd`: Top-level FPGA wrapper (`top_level`) that instantiates `nex030` and board I/O.
- `nex030.vhd`: Main SoC integration (CPU, memory, MFP, flash, bus control).
- `rtl/memory/hyperram.vhd`: HyperRAM controller RTL.
- `rtl/storage/spi_flash.vhd`: SPI/Quad-SPI flash controller RTL.
- `68K30L/`: 68030 core RTL.
- `MFP68901/`: MC68901-compatible peripheral RTL.
- `firmware/bios/`: Monitor/BIOS/boot assembly sources.
- `images/cpm/`: CPM and ramdrive S-record images.
- `firmware/roms/`: ROM artifacts, including BIOS source+binary and flash utility.
- `68881-fpga/`: Git submodule containing an MC68881-compatible FPU core project with its own docs/tests.

## Submodule

This repo includes one git submodule:
- `68881-fpga` -> `https://github.com/mattuna15/68881-fpga.git`

Clone with submodules (or initialize after clone):

```bash
git clone --recurse-submodules <repo-url>
# or
git submodule update --init --recursive
```

## Notes

- The top-level code targets a Xilinx flow (for example `UNISIM`/`STARTUPE2` usage in `rtl/top/main.vhd`).
- This repository currently stores RTL, firmware/ROM sources, and binary images; no checked-in Vivado project (`.xpr`) or constraints (`.xdc`) files are present at the top level.

## License

MIT (`LICENSE`).
