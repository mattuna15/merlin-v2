# 68K30L Review Checklist

This checklist captures work identified by the static CPU review plus local tooling feasibility checks.

## Findings Summary
- Functional risk: unsupported 68030 feature classes are intentional but need explicit coverage/compatibility tracking.
- Integration risk: duplicated interface declarations and local component stubs can drift from true entity contracts.
- Verification gap: no CPU-local simulation/syntax flow is currently available in this workspace.
- Maintainability risk: mixed/non-standard numeric packages are used across CPU files.
- Documentation/provenance gap: module-level docs were missing, and licensing provenance needs explicit clarification.

## Action Items
| ID | Priority | Area | Concrete action | Evidence path(s) | Acceptance criterion |
|---|---|---|---|---|---|
| CPU-001 | P0 | docs | Keep CPU-local docs complete and current (`68K30L/README.md`, `68K30L/agents.md`). | `68K30L/README.md`, `68K30L/agents.md` | Docs exist and match current CPU interfaces and limits. |
| CPU-002 | P0 | verification/tooling | Add a reproducible CPU verification entrypoint (at minimum syntax + elaboration) and document how to run it. | `68K30L/scripts/run_tests.ps1`, `.github/workflows/ghdl-cpu.yml`, `68K30L/README.md` | Done: script + CI path are present and documented. |
| CPU-003 | P0 | licensing/docs | Clarify license provenance for `68K30L` sources and align repository documentation with intended redistribution terms. | `LICENSE`, `68K30L/wf68k30L_top.vhd:34`, `68K30L/wf68k30L_pkg.vhd:13` | Written statement defines authoritative license terms for CPU files and repo distribution. |
| CPU-004 | P1 | maintainability | Define and adopt a policy for numeric packages: no new `std_logic_unsigned`; migrate touched logic toward `numeric_std` semantics. | `68K30L/wf68k30L_top.vhd:209`, `68K30L/wf68k30L_control.vhd:181`, `68K30L/wf68k30L_alu.vhd:78` | Policy documented in module docs; new changes follow it. |
| CPU-005 | P1 | integration | Audit and correct component declaration consistency in `wf68k30L_pkg.vhd` to prevent interface drift and compile ambiguity. | `68K30L/wf68k30L_pkg.vhd:95`, `68K30L/wf68k30L_pkg.vhd:263` | No duplicate/ambiguous declarations; package declarations match implemented entities. |
| CPU-006 | P1 | integration | Reduce risk from duplicated CPU interface stubs in `nex030.vhd` by using direct entity instantiation or enforcing synchronization checks. | `nex030.vhd:36`, `nex030.vhd:313`, `68K30L/wf68k30L_top.vhd:211` | Integration build uses one authoritative CPU interface definition path. |
| CPU-007 | P1 | functional/docs | Create and maintain a feature matrix for intentionally unsupported 68030 features and firmware-visible behavior impact. | `68K30L/wf68k30L_top.vhd:9`, `68K30L/wf68k30L_top.vhd:10`, `68K30L/wf68k30L_top.vhd:14` | Matrix exists and is referenced by BIOS/integration maintainers. |
| CPU-008A | P2 | verification | Expand ALU regression depth beyond smoke checks (status flags, signed/unsigned boundaries, shift/div timing corner cases). | `68K30L/tb/tb_wf68k30L_alu.vhd`, `68K30L/wf68k30L_alu.vhd` | ALU bench includes directed corner-case vectors with explicit expected flags/results. |
| CPU-008B | P2 | verification | Expand opcode decoder regression coverage for trap/legal/illegal decode classes and `NO_LOOP`/`NO_BFOPS` behavior. | `68K30L/tb/tb_wf68k30L_opcode_decoder.vhd`, `68K30L/wf68k30L_opcode_decoder.vhd` | Decoder bench covers representative legal/illegal op classes and generic-gated behavior. |
| CPU-008C | P2 | verification | Add bus-interface fault-path regressions (BERR/HALT retry, AVEC interactions, wait-state combinations). | `68K30L/tb/tb_wf68k30L_bus_interface.vhd`, `68K30L/wf68k30L_bus_interface.vhd` | Bench validates fault/retry/wait-state behavior with assertions. |
| CPU-008D | P2 | verification | Upgrade top-level smoke to program-driven behavioral regression with deterministic vector/image model. | `68K30L/tb/tb_wf68k30L_top_smoke.vhd`, `68K30L/wf68k30L_top.vhd` | Top bench executes a deterministic instruction stream and validates expected bus/control milestones. |

## Suggested Execution Order
1. `CPU-002` verification entrypoint
2. `CPU-003` licensing provenance
3. `CPU-005` package declaration cleanup plan
4. `CPU-006` integration contract hardening
5. `CPU-007` feature matrix
6. `CPU-008A` through `CPU-008D` targeted regressions

## Notes
- This checklist should be updated whenever CPU behavior, public interfaces, or bus timing assumptions change.
