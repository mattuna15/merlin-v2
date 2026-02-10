# MC68881 BIU Coprocessor Interface Checklist

This checklist tracks the remaining work to reach full MC68020/030 + MC68881 BIU-compatible behavior.

## Implemented in this change
- [x] F-line (`IR[15:12]=1111`) opcodes are dispatched to a dedicated `COPROC` opcode class in the decoder.
- [x] Decoder no longer raises an immediate trap for all F-line words; dispatch proceeds through the control path.
- [x] Control path enters extension-word fetch sequencing for `COPROC` operations.
- [x] Function-code path documents and preserves bus-only coprocessor interfacing (no custom cp handshake pins).

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
