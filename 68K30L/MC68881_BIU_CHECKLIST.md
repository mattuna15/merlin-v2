# MC68881 BIU Coprocessor Interface Checklist

This checklist tracks the remaining work to reach full MC68020/030 + MC68881 BIU-compatible behavior.

## Implemented in this change
- [x] A dedicated `COPROC` opcode class exists in shared CPU opcode typing for staged integration work.
- [x] Legacy F-line trap behavior is intentionally preserved until dedicated `COPROC` execute-state sequencing is implemented.
- [x] Control path explicitly avoids reusing generic `FETCH_EXWORD_1` indexed-address extension parsing for `COPROC`.
- [x] A dedicated `FETCH_COPROC_EW` state fetches one coprocessor extension word without indexed-EA side parsing.
- [x] Function-code path documents bus-only coprocessor interfacing intent (no custom cp handshake pins).

## Next steps (required for full architectural compatibility)
- [ ] Decode full coprocessor extension-word formats (FMOVE, FSAVE/FRESTORE, arithmetic/transcendental, FP branches/traps).
- [ ] Add operand-transfer micro-sequencing that uses standard bus cycles and DSACK*-driven wait states.
- [ ] Distinguish coprocessor transfer function-code usage for operand/data phases per 68020/030 coprocessor rules.
- [ ] Implement no-coprocessor response fallback to Illegal Instruction (not generic bus-error) at instruction level.
- [ ] Implement FSAVE/FRESTORE variable-length frame transfer sequencing and restart/abort handling.
- [ ] Implement FPIAR/exception-PC reporting and coprocessor exception synchronization in exception handler interaction.
- [ ] Add top-level/system tests with an external MC68881-compatible VHDL FPU model attached via normal address decode.

## Validation additions pending
- [ ] Add directed decoder tests for FMOVE/FSAVE/FRESTORE class patterns.
- [ ] Add bus-interface tests that verify coprocessor cycles stall only on DSACK* latency.
- [ ] Add integration test that verifies Illegal Instruction when coprocessor decode target is absent.
