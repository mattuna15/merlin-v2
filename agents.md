# agents.md

## Repository overview
- FPGA 68k computer platform centered on a pipelined 68030 (`nex030.vhd`).
- Top-level wrapper and board startup logic live in `rtl/top/main.vhd` (entity `top_level`).
- Major RTL blocks:
  - 68030 core: `68K30L/`
  - MC68901-compatible MFP: `MFP68901/`
  - HyperRAM controller: `rtl/memory/hyperram.vhd`
  - Quad-SPI flash controller: `rtl/storage/spi_flash.vhd`
- Firmware and images:
  - BIOS/boot sources: `firmware/bios/`
  - ROM payloads/utilities: `firmware/roms/`
  - CPM/ramdrive S-record images: `images/cpm/`
- `68881-fpga/` is a separate MC68881 submodule with its own `README.md` and `agents.md`.

## Development notes
- Keep top-level documentation in sync with structural changes (`README.md` and this file).
- Treat `nex030.vhd` as the SoC integration contract: CPU bus timing, address decode, and device selection should stay coherent when adding/removing peripherals.
- Preserve the current decode intent unless deliberately changing the memory map:
  - Boot ROM/vector window around `0x00FCxxxx` plus startup vectors.
  - Stack RAM at low memory (`<= 0x0000FFFF`).
  - Flash windows at `0x00FExxxx` and `0x01xxxxxx` (extended ROM area).
  - MFP register space at `0x00FDxxxx`.
  - HyperRAM for the main lower address space below `0x00FC0000` (outside stack window).
- Any memory-map change must be reflected in firmware sources under `firmware/bios/` and ROM assets under `firmware/roms/` as needed.
- Keep UART/MFP behavior stable for monitor console compatibility (Easy68k-style console paths are firmware-visible behavior).
- Maintain VHDL-2008 compatibility and avoid introducing unnecessary vendor lock-in beyond existing top-level primitives (`UNISIM`/`STARTUPE2` in `rtl/top/main.vhd`).
- Follow Vivado/VRFC parameter mode rules in VHDL subprograms: never read an `out` parameter and never write to an `in` parameter.
- Prefer small, testable integration changes in `nex030.vhd`; large feature work should be split into peripheral-local RTL updates plus minimal top-level wiring.
- Do not modify `68881-fpga/` from top-level tasks unless the change explicitly targets the FPU submodule.
