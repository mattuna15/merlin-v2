# 68K30L CPU Core

## Purpose and Scope
`68K30L/` contains the pipelined 68030-compatible CPU core used by this project. The integration point to the SoC is `WF68K30L_TOP` in `68K30L/wf68k30L_top.vhd`.

This folder is CPU RTL only. Board wiring, memory map decode, and peripheral arbitration are handled in `nex030.vhd`.

## File Roles
- `68K30L/wf68k30L_top.vhd`: Top-level structural CPU integration.
- `68K30L/wf68k30L_pkg.vhd`: Shared types and component declarations.
- `68K30L/wf68k30L_control.vhd`: Main control state machines and hazard handling.
- `68K30L/wf68k30L_opcode_decoder.vhd`: Decode logic and loop/bitfield decode controls.
- `68K30L/wf68k30L_bus_interface.vhd`: External bus protocol, data path, arbitration handshakes.
- `68K30L/wf68k30L_exception_handler.vhd`: Exception/interrupt stack and vector handling.
- `68K30L/wf68k30L_alu.vhd`: Arithmetic/logic execution and condition code logic.
- `68K30L/wf68k30L_address_registers.vhd`: Address register file and effective address support.
- `68K30L/wf68k30L_data_registers.vhd`: Data register file.

## Implemented vs. Intentionally Missing
Per core header notes in `68K30L/wf68k30L_top.vhd:9` through `68K30L/wf68k30L_top.vhd:14`:
- Implemented as a pipelined 68030-compatible core.
- Intentionally missing MMU and cache behavior.
- Coprocessor support is under active integration: F-line decode is now dispatched to a CPU coprocessor path for BIU-based external interfacing, but full 68881 execution semantics are still pending.
- MMU operations like `PFLUSH/PLOAD/PMOVE/PTEST` are not implemented.

## Public CPU Interface
Top entity: `WF68K30L_TOP` (`68K30L/wf68k30L_top.vhd:211`).

Generics (`68K30L/wf68k30L_top.vhd:212` through `68K30L/wf68k30L_top.vhd:216`):
- `VERSION : std_logic_vector(31 downto 0)`
- `NO_PIPELINE : boolean`
- `NO_LOOP : boolean`
- `NO_BFOPS : boolean`

Key bus/control ports (`68K30L/wf68k30L_top.vhd:242` through `68K30L/wf68k30L_top.vhd:265`):
- Asynchronous bus: `ASn`, `DSn`, `DSACKn`, `RWn`, `RMCn`, `ECSn`, `OCSn`, `DBENn`, `SIZE`, `BUS_EN`
- Synchronous bus termination: `STERMn`
- Error/exception: `BERRn`, `AVECn`
- Arbitration: `BRn`, `BGn`, `BGACKn`

## Integration Notes for `nex030.vhd`
- The SoC-side component declaration mirrors CPU generics in `nex030.vhd:37` through `nex030.vhd:41`.
- CPU instantiation is at `nex030.vhd:313`.
- Current integration ties some external controls to fixed defaults:
  - `cpu_bgack_n_s <= '1'` (`nex030.vhd:466`)
  - `cpu_br_n_s <= '1'` (`nex030.vhd:467`)
  - `cpu_sterm_n_s <= '1'` (`nex030.vhd:468`)
- `HALT_INn` is currently tied to reset input (`nex030.vhd:321`), which is a board policy decision and should be kept intentional.

## Known Limitations and Compatibility Notes
- The CPU RTL uses `ieee.std_logic_unsigned` in multiple files (for example `68K30L/wf68k30L_top.vhd:209`), which is widely supported but less portable than strict `numeric_std` style.
- `68K30L/wf68k30L_pkg.vhd` contains duplicated `AR_IN_USE` declarations in the same component interface (`68K30L/wf68k30L_pkg.vhd:95` and `68K30L/wf68k30L_pkg.vhd:263`), which increases drift risk and should be reviewed.
- Top-level repo license is MIT (`LICENSE`), while CPU source headers mention CERN OHL text, so provenance and relicensing intent should be explicitly documented.

## Numeric Package Policy
Policy for `68K30L/` maintenance:
- Do not introduce new `ieee.std_logic_unsigned` or `ieee.std_logic_arith` usage in any new or modified CPU RTL file.
- Prefer `ieee.numeric_std` semantics (`unsigned`/`signed` with explicit casts) for all new arithmetic and comparisons.
- When touching logic in a file that still uses legacy numeric packages, migrate only the touched expressions to `numeric_std` style unless a full-file conversion is low risk and can be validated in the same change.
- Keep behavior identical during incremental migration (no intentional decode/timing/flag changes unless separately scoped and documented).

## Verification Status
Static review completed for all CPU files listed above.

Local feasibility check for HDL tools:
- `where.exe ghdl` -> not found
- `where.exe xvhdl` -> not found

Result: syntax/elaboration checks were not run in this pass due to missing local HDL tools.

CPU-local regression structure now exists:
- Testbenches: `68K30L/tb/`
- Runner script: `68K30L/scripts/run_tests.ps1`
- CI workflow: `.github/workflows/ghdl-cpu.yml`
- Optional pre-push hook: `.githooks/pre-push`

## Running CPU Simulations
Use the repository-level PowerShell test script:

```powershell
powershell -ExecutionPolicy Bypass -File 68K30L/scripts/run_tests.ps1
```

The script uses `GHDL_EXE` when set. If unset, it falls back to:
1. `C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe`
2. `ghdl` on `PATH`

Direct GHDL example:

```sh
ghdl -a --std=08 --ieee=synopsys 68K30L/wf68k30L_pkg.vhd 68K30L/wf68k30L_alu.vhd 68K30L/tb/tb_wf68k30L_alu.vhd
ghdl -e --std=08 --ieee=synopsys tb_wf68k30L_alu
ghdl -r --std=08 --ieee=synopsys tb_wf68k30L_alu --assert-level=error
```

Current CPU benches:
- `68K30L/tb/tb_wf68k30L_alu.vhd`
- `68K30L/tb/tb_wf68k30L_opcode_decoder.vhd`
- `68K30L/tb/tb_wf68k30L_bus_interface.vhd`
- `68K30L/tb/tb_wf68k30L_top_smoke.vhd`

Optional local pre-push guard:

```sh
git config core.hooksPath .githooks
```

## Follow-up Work
Actionable follow-up items are tracked in `68K30L/REVIEW_CHECKLIST.md`.

MC68881 BIU integration-specific remaining work is tracked in `68K30L/MC68881_BIU_CHECKLIST.md`.
