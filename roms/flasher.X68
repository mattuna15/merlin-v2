; Memory layout
RAMBASE     equ     $0
RAMLIMIT    equ     $FC0000

IOBASE      equ     $fD0000

ROMBASE     equ     $FC0000

; MFP Location
MFPBASE     equ     IOBASE  

;; MFP Registers on "fixed" boards
; MFP GPIO Registers
MFP_GPDR    equ     MFPBASE+$01
MFP_AER     equ     MFPBASE+$03
MFP_DDR     equ     MFPBASE+$05
; MFP Interrupt Controller Registers
MFP_IERA    equ     MFPBASE+$07
MFP_IERB    equ     MFPBASE+$09
MFP_IPRA    equ     MFPBASE+$0B
MFP_IPRB    equ     MFPBASE+$0D
MFP_ISRA    equ     MFPBASE+$0F
MFP_ISRB    equ     MFPBASE+$11
MFP_IMRA    equ     MFPBASE+$13
MFP_IMRB    equ     MFPBASE+$15
MFP_VR      equ     MFPBASE+$17
; MFP Timer Registers
MFP_TACR    equ     MFPBASE+$19
MFP_TBCR    equ     MFPBASE+$1B
MFP_TCDCR   equ     MFPBASE+$1D
MFP_TADR    equ     MFPBASE+$1F
MFP_TBDR    equ     MFPBASE+$21
MFP_TCDR    equ     MFPBASE+$23
MFP_TDDR    equ     MFPBASE+$25
; MFP USART Registers
MFP_SCR     equ     MFPBASE+$27
MFP_UCR     equ     MFPBASE+$29
MFP_RSR     equ     MFPBASE+$2B
MFP_TSR     equ     MFPBASE+$2D
MFP_UDR     equ     MFPBASE+$2F
FLASH_BASE equ $FE0000

    ORG    FLASH_BASE
START:                  ; first instruction of program
    or.w    #$0700,SR                 ; Disable interrupts for now  

    lea.l   SZ_BOOT,A0             ; Load first string into A0
    jsr   $FC00A0 
    
flash:
    MOVE.L  #10000,D0  ; Load loop counter for 50MHz CPU
    move.b  #$07,MFP_GPDR 
DELAY_LOOP:
    NOP                  ; No operation, takes some cycles
    SUBQ.L  #1,D0        ; Subtract 1 from D0
    BNE     DELAY_LOOP   ; Branch if not equal to zero
    
    move.b  #$06,MFP_GPDR 
    MOVE.L  #10000,D0  ; Load loop counter for 50MHz CPU
DELAY_LOOP1:
    NOP                  ; No operation, takes some cycles
    SUBQ.L  #1,D0        ; Subtract 1 from D0
    BNE     DELAY_LOOP1   ; Branch if not equal to zero    

    jmp flash


* Put program code here

    SIMHALT             ; halt simulator

* Put variables and constants here

SZ_BOOT    dc.b 13,10,'Running from flash rom...',13,10,0


SZ_CRLF         dc.b        $D, $A, 0

                ds.l	1					* ensure even


    END    START        ; last line of source



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
