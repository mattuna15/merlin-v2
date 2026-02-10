Plan

68K30L CPU Review + Module Documentation Plan
Summary
Perform a focused review of the 68K30L 68030 core implementation, then add module-local documentation:

README.md
agents.md
REVIEW_CHECKLIST.md (standalone actionable checklist derived from findings)
This will be a static review plus feasibility checks (tooling/build availability), with findings prioritized by risk and converted into concrete follow-up tasks.

Scope
In scope:

CPU RTL under *.vhd
CPU integration touchpoints in nex030.vhd
Existing repo-level docs/licensing context needed to accurately document module constraints
Out of scope:

Functional RTL changes to CPU logic
Changes to 68881-fpga/
Firmware/ROM behavior changes
Implementation Steps
Baseline review pass
Inspect each CPU file for architecture boundaries and responsibilities:
wf68k30L_top.vhd
wf68k30L_control.vhd
wf68k30L_opcode_decoder.vhd
wf68k30L_bus_interface.vhd
wf68k30L_exception_handler.vhd
wf68k30L_alu.vhd
wf68k30L_address_registers.vhd
wf68k30L_data_registers.vhd
wf68k30L_pkg.vhd
Extract review findings grouped by:
Functional risk
Integration risk
Verification/test coverage gaps
Maintainability/toolchain portability gaps
Documentation/provenance gaps
Feasibility checks
Detect local HDL tool availability (ghdl, xvhdl, etc.).
If present, run non-mutating syntax/elaboration checks for CPU files.
If absent, explicitly record limitation and convert it into checklist actions.
Create README.md
Include these required sections:
Purpose and design scope
What is implemented vs intentionally missing (MMU/cache/coprocessor features)
Top-level entity and generics (WF68K30L_TOP, VERSION, NO_PIPELINE, NO_LOOP, NO_BFOPS)
Bus interface expectations (ASn/DSn/DSACKn/STERMn/RMCn/BERRn, arbitration signals)
Integration notes for nex030.vhd
Known limitations and compatibility notes
Verification status and current gaps
Pointer to REVIEW_CHECKLIST.md
Create agents.md
Add module-specific guardrails for future changes:
Treat WF68K30L_TOP interface as a stable contract unless deliberately changed
Keep wf68k30L_pkg.vhd declarations consistent with all component entities
Preserve bus timing semantics expected by nex030.vhd
Require checklist update when behavior-affecting CPU changes are made
Prefer CPU-local changes before SoC-wide edits
Keep VHDL-2008 compatibility and avoid non-portable package usage in new code
Do not touch 68881-fpga/ from CPU-only tasks
Create REVIEW_CHECKLIST.md
Convert findings into actionable tasks with:
ID
Priority (P0/P1/P2)
Area (functional/integration/verification/docs/licensing/tooling)
Concrete action
Evidence path(s)
Acceptance criterion
Seed checklist with currently identified work items:
Add CPU-local documentation (README/agents)
Define CPU verification entrypoint (at least syntax/elaboration flow)
Clarify licensing/provenance mismatch risk between repo MIT and CPU file headers
Define policy for legacy numeric packages (std_logic_unsigned) in future edits
Create instruction/feature coverage matrix for unsupported 68030 features
Cross-reference consistency
Ensure README.md references REVIEW_CHECKLIST.md.
Ensure agents.md references the checklist maintenance rule.
Keep wording aligned with top-level agents.md constraints.
Public APIs / Interfaces / Types
No RTL interface changes are planned.
Documentation will explicitly codify existing public CPU interface:

WF68K30L_TOP ports and generics
Expected integration behavior used by nex030.vhd
Test Cases and Scenarios
Documentation completeness check
Verify all three files exist and contain required sections.
Interface documentation accuracy check
Cross-check documented WF68K30L_TOP generics/ports against wf68k30L_top.vhd.
Review traceability check
Each checklist item must reference concrete source file evidence.
Feasibility/tooling check
Confirm whether HDL toolchain exists locally and record exact outcome in checklist.
No unintended code mutation check
Confirm only new documentation files are added, with no RTL edits.
Acceptance Criteria
README.md exists and documents architecture, limitations, integration, and verification status.
agents.md exists and gives actionable module-specific engineering rules.
REVIEW_CHECKLIST.md exists with prioritized, evidence-backed tasks.
Findings are practical and implementation-oriented, not generic commentary.
No RTL behavior changes introduced.
Assumptions and Defaults
Review mode: Static + feasibility checks.
Checklist location: Standalone file REVIEW_CHECKLIST.md.
If no HDL simulator/compiler is installed, verification items are still captured with explicit next actions.
Top-level docs are not modified unless needed to prevent contradiction.