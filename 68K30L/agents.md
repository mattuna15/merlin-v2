# agents.md

## Module Overview
- Scope: 68030-compatible CPU RTL in `68K30L/`.
- Integration contract: `WF68K30L_TOP` in `68K30L/wf68k30L_top.vhd`.
- SoC wiring lives in `nex030.vhd`; CPU-local tasks should stay CPU-local unless an interface change is explicitly required.

## Guardrails
- Treat `WF68K30L_TOP` generics and ports as a stable public contract unless the task explicitly changes integration behavior.
- Keep `68K30L/wf68k30L_pkg.vhd` declarations synchronized with entity ports used by all CPU submodules.
- Preserve bus timing semantics expected by `nex030.vhd` (`ASn/DSn/DSACKn/STERMn/RMCn/BERRn`, arbitration pins).
- Prefer minimal, peripheral-local or CPU-local edits before SoC-wide rewiring in `nex030.vhd`.
- Maintain VHDL-2008 compatibility.
- For new CPU code, prefer `numeric_std`-style arithmetic and avoid introducing additional non-standard numeric package usage.
- Do not modify `68881-fpga/` from CPU-only tasks.
- Maintain self-checking benches in `68K30L/tb/` for behavior changes in covered modules (`ALU`, opcode decoder, bus interface, and top-level smoke path).
- Keep `68K30L/scripts/run_tests.ps1` and `.github/workflows/ghdl-cpu.yml` synchronized with the current bench list.
- If using local push guards, keep `.githooks/pre-push` synchronized with the same bench list.

## Review and Checklist Policy
- If a change affects CPU behavior, decode, hazards, exception flow, or bus signaling, update `68K30L/REVIEW_CHECKLIST.md`.
- Add or update evidence paths in checklist items so follow-up work stays traceable.
- Keep `68K30L/README.md` in sync with interface or architectural changes.
