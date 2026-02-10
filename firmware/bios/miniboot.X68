*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------

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
HYPERRAM_BASE equ $00001000

; Initialisation
INIT_SSP    equ     $1000
INIT_PC     equ     ROMBASE

; Base vector for MFP exceptions
MFP_VECBASE equ     $40

*    org RAMBASE
*RESET:
*    dc.l    INIT_SSP
*    dc.l    INIT_PC 
*    
    ORG ROMBASE
START:                  ; first instruction of program
    ds.w 0
    or.w    #$0700,SR                 ; Disable interrupts for now    

    jsr   INITMFP                   ; Initialise MC68901
    
    lea.l   SZ_FLASH,A0             ; Load first string into A0
    bsr   EARLY_PRINTLN 

CHECK:    
    move.w (FLASH_BASE), D0
    cmp   #$007c,D0
    bne CHECK
    jsr OUT4X    
        ; Indicate success and return
    move.b  #$03,MFP_GPDR             ; Turn on GPIO #1,2 (Green LED)
    
    lea.l   SZ_HYPERRAM,A0             ; Load first string into A0
    bsr.s   EARLY_PRINTLN
    move.l #$12345678,HYPERRAM_BASE
    move.l (HYPERRAM_BASE), D0
    jsr OUT8X    
    
    move.b  #$07,MFP_GPDR             ; Turn on GPIO #1,2,3 (Green LED)
       
    lea.l   SZ_BOOT,A0             ; Load first string into A0
    bsr.s   EARLY_PRINTLN 
    
    jmp FLASH_BASE
        
* Put program code here

    SIMHALT             ; halt simulator
    
    
PUTCHAR
    btst.b  #7,MFP_TSR                ; Is transmit buffer empty?
    beq.s   PUTCHAR               ; Busywait if not
    
    move.b  D0,MFP_UDR
    rts

GETCHAR
    btst.b  #7,MFP_RSR                ; Is transmit buffer empty?
    beq.s   GETCHAR               ; Busywait if not
    
    move.b  MFP_UDR, D0
    rts
    
; PRINT null-terminated string pointed to by A0
;
; Only used during early init; Buffered serial driver will take
; over the UART later on...
;
; Trashes: D0, MFP_UDR
; Modifies: A0 (Will point to address after null terminator)
EARLY_PRINT:
    move.b  (A0)+,D0                  ; Get next character
    tst.b   D0                        ; Is it null?
    beq.s   .PRINT_DONE               ; ... we're done if so.

.BUFF_WAIT:
    btst.b  #7,MFP_TSR                ; Is transmit buffer empty?
    beq.s   .BUFF_WAIT                ; Busywait if not
    
    move.b  D0,MFP_UDR                ; ... otherwise, give character to the MFP
    bra.s   EARLY_PRINT               ; and loop
.PRINT_DONE:    
    rts                               ; We're done
    
; PRINT null-terminated string pointed to by A0 followed by CRLF.
;
; Only used during early init; Buffered serial driver will take
; over the UART later on...
;
; Trashes: D0, MFP_UDR
; Modifies: A0 (Will point to address after null terminator)
EARLY_PRINTLN:
    bsr.s   EARLY_PRINT               ; Print callers message
    move.l  A0,-(A7)                  ; Stash A0 to restore later
    
    lea     SZ_CRLF,A0                ; Load CRLF...
    bsr.s   EARLY_PRINT               ; ... and print it
        
    move.l  (A7)+,A0                  ; Restore A0
    rts
; Initialise MFP
;
; Trashes: D0
; Modifies: MFP Regs
INITMFP:
    ; GPIOs
    move.b  #$FF,MFP_DDR              ; All GPIOs are output
    
    ; Timer setup - Timer D controls serial clock, C is kernel tick
    move.b  #$5C,MFP_TCDR             ; Timer C count is 92 for 50Hz (interrupt on rise and fall so 100Hz)
    move.b  #$18,MFP_TDDR             ; Timer D count is 24 for (19.2KHz, divided by 2 for 9600 baud)
    move.b  #$71,MFP_TCDCR            ; Enable timer C with /200 and D with /4 prescaler
    
    ; USART setup
    move.b  #$08,MFP_UCR              ; Fundamental clock, async, 8N1
    move.b  #$05,MFP_TSR              ; Set pin state high and enable transmitter

    ; Interrupt setup - Enable timer C interrupt for kernel tick
    move.l  #MFP_VECBASE,D0           ; Set up the base MFP vector at 0x40 (first 16 user vectors)...
    or.l    #8,D0                     ; ... and set software-end-of-interrupt mode
    move.b  D0,MFP_VR                 ; ... then write to MFP vector register
    or.b    #$20,MFP_IERB             ; Enable Timer C interrupt, but leave it masked for now
                                      ; (kmain will call START_HEART later)
    
    ; Indicate success and return
    move.b  #$01,MFP_GPDR             ; Turn on GPIO #0 (Green LED)
    rts
    
OUT1X    MOVE.W   D0,-(A7)          Save D0
         AND.B    #$0F,D0           Mask off MS nybble
         ADD.B    #$30,D0           Convert to ASCII
         CMP.B    #$39,D0           ASCII = HEX + $30
         BLS.S    OUT1X1            If ASCII <= $39 then print and exit
         ADD.B    #$07,D0           Else ASCII := HEX + 7
OUT1X1   BSR      PUTCHAR           Print the character
         MOVE.W   (A7)+,D0          Restore D0
         RTS

OUT2X    ROR.B    #4,D0             Get MS nybble in LS position
         BSR      OUT1X             Print MS nybble
         ROL.B    #4,D0             Restore LS nybble
         BRA      OUT1X             Print LS nybble and return

OUT4X    ROR.W    #8,D0             Get MS byte in LS position
         BSR      OUT2X             Print MS byte
         ROL.W    #8,D0             Restore LS byte
         BRA      OUT2X             Print LS byte and return

OUT8X    SWAP     D0                Get MS word in LS position
         BSR      OUT4X             Print MS word
         SWAP     D0                Restore LS word
         BRA      OUT4X             Print LS word and return
         
         

* Put variables and constants here

                ds.l 0

SZ_FLASH       dc.b 13,10,'Testing Flash Memory...',13,10,0
SZ_HYPERRAM    dc.b 13,10,'Testing Hyperram Memory...',13,10,0
SZ_BOOT    dc.b 13,10,'Booting from flash..',13,10,0


SZ_CRLF         dc.b        $D, $A, 0

                ds.l	1					* ensure even

    END    START        ; last line of source


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
