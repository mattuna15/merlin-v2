# 68K30L Review Checklist

This checklist captures work identified by the static CPU review plus local tooling feasibility checks.

## Findings Summary
- Functional risk: unsupported 68030 feature classes are intentional but need explicit coverage/compatibility tracking.
- Integration risk: duplicated interface declarations and local component stubs can drift from true entity contracts.
- Verification status: CPU-local GHDL flow and smoke benches are now in place; deeper behavioral coverage is still pending.
- Maintainability risk: mixed/non-standard numeric packages are used across CPU files.
- Documentation/provenance gap: module-level docs now exist; licensing provenance still needs explicit clarification.

## Completed Work
- CPU-local docs created and linked: `68K30L/README.md`, `68K30L/agents.md`, `68K30L/REVIEW_CHECKLIST.md`.
- CPU verification harness added:
  - `68K30L/tb/tb_wf68k30L_alu.vhd`
  - `68K30L/tb/tb_wf68k30L_opcode_decoder.vhd`
  - `68K30L/tb/tb_wf68k30L_bus_interface.vhd`
  - `68K30L/tb/tb_wf68k30L_top_smoke.vhd`
  - `68K30L/scripts/run_tests.ps1`
  - `.github/workflows/ghdl-cpu.yml`
  - `.githooks/pre-push`
- Local regression execution validated with:
  - `powershell -ExecutionPolicy Bypass -File 68K30L/scripts/run_tests.ps1`
  - Result: all four benches pass in current workspace/toolchain.

## Action Items
- [x] **CPU-001**
  Priority: `P0`  
  Area: `docs`  
  Action: Keep CPU-local docs complete and current (`68K30L/README.md`, `68K30L/agents.md`).  
  Evidence: `68K30L/README.md`, `68K30L/agents.md`, `68K30L/REVIEW_CHECKLIST.md`  
  Acceptance: Done: docs exist, cross-reference simulation flow, and reflect current CPU interfaces/limits.

- [x] **CPU-002**
  Priority: `P0`  
  Area: `verification/tooling`  
  Action: Add a reproducible CPU verification entrypoint (at minimum syntax + elaboration) and document how to run it.  
  Evidence: `68K30L/scripts/run_tests.ps1`, `.github/workflows/ghdl-cpu.yml`, `68K30L/README.md`  
  Acceptance: Done: script + CI path are present and documented.

- [ ] **CPU-003**
  Priority: `P0`  
  Area: `licensing/docs`  
  Action: Clarify license provenance for `68K30L` sources and align repository documentation with intended redistribution terms; treat this as a blocker until explicit upstream license terms are confirmed.  
  Evidence: `LICENSE`, `68K30L/wf68k30L_top.vhd:34`, `68K30L/wf68k30L_pkg.vhd:13`, upstream origin `http://experiment-s.de/en/download/` (`Index of /Configware/2K25A/rtl`, per project provenance note), project page `http://experiment-s.de/en/progress/` (reported source project context, potentially inactive), and current finding: no explicit license text identified on the cited public source pages.  
  Acceptance: Repository includes a written provenance statement that either (1) cites explicit upstream license terms for `68K30L`/`MFP68901`, or (2) marks these components as license-unresolved and not redistributable until upstream permission/license is obtained.

- [x] **CPU-004**
  Priority: `P1`  
  Area: `maintainability`  
  Action: Define and adopt a policy for numeric packages: no new `std_logic_unsigned`; migrate touched logic toward `numeric_std` semantics.  
  Evidence: `68K30L/README.md` (`Numeric Package Policy`), `68K30L/agents.md` (`Numeric package policy for CPU RTL`), existing legacy usage references `68K30L/wf68k30L_top.vhd:209`, `68K30L/wf68k30L_control.vhd:181`, `68K30L/wf68k30L_alu.vhd:78`  
  Acceptance: Done: policy is explicitly documented in module docs and applies to new/touched CPU changes.

- [ ] **CPU-005**
  Priority: `P1`  
  Area: `integration`  
  Action: Audit and correct component declaration consistency in `wf68k30L_pkg.vhd` to prevent interface drift and compile ambiguity.  
  Evidence: `68K30L/wf68k30L_pkg.vhd:95`, `68K30L/wf68k30L_pkg.vhd:263`  
  Acceptance: No duplicate/ambiguous declarations; package declarations match implemented entities.

- [ ] **CPU-006**
  Priority: `P1`  
  Area: `integration`  
  Action: Reduce risk from duplicated CPU interface stubs in `nex030.vhd` by using direct entity instantiation or enforcing synchronization checks.  
  Evidence: `nex030.vhd:36`, `nex030.vhd:313`, `68K30L/wf68k30L_top.vhd:211`  
  Acceptance: Integration build uses one authoritative CPU interface definition path.

- [ ] **CPU-007**
  Priority: `P1`  
  Area: `functional/docs`  
  Action: Create and maintain a feature matrix for intentionally unsupported 68030 features and firmware-visible behavior impact.  
  Evidence: `68K30L/wf68k30L_top.vhd:9`, `68K30L/wf68k30L_top.vhd:10`, `68K30L/wf68k30L_top.vhd:14`  
  Acceptance: Matrix exists and is referenced by BIOS/integration maintainers.

- [ ] **CPU-008A**
  Priority: `P2`  
  Area: `verification`  
  Action: Expand ALU regression depth beyond smoke checks (status flags, signed/unsigned boundaries, shift/div timing corner cases).  
  Evidence: `68K30L/tb/tb_wf68k30L_alu.vhd`, `68K30L/wf68k30L_alu.vhd`  
  Acceptance: ALU bench includes directed corner-case vectors with explicit expected flags/results.

- [ ] **CPU-008B**
  Priority: `P2`  
  Area: `verification`  
  Action: Expand opcode decoder regression coverage for trap/legal/illegal decode classes and `NO_LOOP`/`NO_BFOPS` behavior.  
  Evidence: `68K30L/tb/tb_wf68k30L_opcode_decoder.vhd`, `68K30L/wf68k30L_opcode_decoder.vhd`  
  Acceptance: Decoder bench covers representative legal/illegal op classes and generic-gated behavior.

- [ ] **CPU-008C**
  Priority: `P2`  
  Area: `verification`  
  Action: Add bus-interface fault-path regressions (BERR/HALT retry, AVEC interactions, wait-state combinations).  
  Evidence: `68K30L/tb/tb_wf68k30L_bus_interface.vhd`, `68K30L/wf68k30L_bus_interface.vhd`  
  Acceptance: Bench validates fault/retry/wait-state behavior with assertions.

- [ ] **CPU-008D**
  Priority: `P2`  
  Area: `verification`  
  Action: Upgrade top-level smoke to program-driven behavioral regression with deterministic vector/image model.  
  Evidence: `68K30L/tb/tb_wf68k30L_top_smoke.vhd`, `68K30L/wf68k30L_top.vhd`  
  Acceptance: Top bench executes a deterministic instruction stream and validates expected bus/control milestones.


- [ ] **CPU-009**
  Priority: `P0`  
  Area: `coprocessor/interface`  
  Action: Complete MC68881 BIU coprocessor integration sequencing (FMOVE classes, FSAVE/FRESTORE, Illegal fallback on no-response, and exception/FPIAR synchronization).  
  Evidence: `68K30L/wf68k30L_opcode_decoder.vhd`, `68K30L/wf68k30L_control.vhd`, `68K30L/wf68k30L_top.vhd`, `68K30L/MC68881_BIU_CHECKLIST.md`  
  Acceptance: CPU executes representative F-line instruction streams against an external MC68881-compatible BIU model with correct exception/reporting behavior.

## Suggested Execution Order
1. `CPU-003` licensing provenance
2. `CPU-005` package declaration cleanup plan
3. `CPU-006` integration contract hardening
4. `CPU-007` feature matrix
5. `CPU-008A` through `CPU-008D` targeted regressions

## Notes
- This checklist should be updated whenever CPU behavior, public interfaces, or bus timing assumptions change.
