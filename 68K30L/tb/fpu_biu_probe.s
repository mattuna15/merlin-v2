; Minimal MC68030 + MC68881 BIU probe program.
; Intended for simulation/bring-up, not ROM-integrated production firmware.
;
; 1) Probe FPCR/FPSR access.
; 2) Run one arithmetic op.
; 3) Execute FSAVE/FRESTORE.
; 4) Confirm Illegal Instruction path when FPU is absent.

        cpu 68030
        fpu 68881

        section .text
        xdef _start

_start:
        lea     result_area,a0

; ---- (1) Probe via FPCR/FPSR transfers ----
        fmove.l #$00000000,fpcr
        fmove.l fpsr,d0
        move.l  d0,(a0)+

; ---- (2) Simple arithmetic ----
        fmove.s #1.5,fp0
        fadd.s  #2.25,fp0
        fmove.s fp0,(a0)+

; ---- (3) FSAVE/FRESTORE round trip ----
        lea     fpu_ctx,a1
        fsave   (a1)
        frestore (a1)

; ---- (4) Illegal instruction fallback check ----
; Disable/ungate external FPU decode in the testbench/platform before this block.
; If no coprocessor responds, executing an F-line instruction must vector through
; Illegal Instruction (vector #4).
        clr.l   illegal_seen
        fmove.l fpsr,d1
        move.l  illegal_seen,d2
        move.l  d2,(a0)+

done:
        bra.s   done

        section .vectors
        org     $10
        dc.l    illegal_handler

        section .text
illegal_handler:
        move.l  #1,illegal_seen
        rte

        section .bss
result_area:     ds.b 32
fpu_ctx:         ds.b 256
illegal_seen:    ds.l 1
